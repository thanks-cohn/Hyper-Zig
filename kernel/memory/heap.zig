const log = @import("../log.zig");
const uart = @import("../console/uart.zig");

pub const heap_total_bytes: usize = 16 * 1024;
pub const heap_kind = "bump-reset";
pub const allocator_name = "kernel-bump-reset-v0";

pub const Error = enum {
    none,
    out_of_memory,
    invalid_size,
    invalid_alignment,
};

pub const Stats = struct {
    total_bytes: usize,
    used_bytes: usize,
    free_bytes: usize,
    alloc_count: usize,
    reset_count: usize,
    overflow_count: usize,
    last_alloc_size: usize,
    last_alloc_ok: bool,
    last_error: Error,
};

var heap_buffer: [heap_total_bytes]u8 align(16) = undefined;
var used_bytes: usize = 0;
var alloc_count: usize = 0;
var reset_count: usize = 0;
var overflow_count: usize = 0;
var last_alloc_size: usize = 0;
var last_alloc_ok: bool = false;
var last_error: Error = .none;

pub fn init() void {
    used_bytes = 0;
    alloc_count = 0;
    reset_count = 0;
    overflow_count = 0;
    last_alloc_size = 0;
    last_alloc_ok = false;
    last_error = .none;
    log.info("HEAP", "HEAP000", "kernel heap initialized; bump-reset allocator active");
}

pub fn alloc(size: usize, alignment: usize) ?[*]u8 {
    last_alloc_size = size;

    if (size == 0) {
        last_alloc_ok = false;
        last_error = .invalid_size;
        return null;
    }
    if (!validAlignment(alignment)) {
        last_alloc_ok = false;
        last_error = .invalid_alignment;
        return null;
    }

    const base = @intFromPtr(&heap_buffer[0]);
    const current = base + used_bytes;
    const aligned = alignForward(current, alignment) orelse {
        overflow_count += 1;
        last_alloc_ok = false;
        last_error = .out_of_memory;
        return null;
    };
    const padding = aligned - current;
    if (padding > heap_total_bytes - used_bytes) {
        overflow_count += 1;
        last_alloc_ok = false;
        last_error = .out_of_memory;
        return null;
    }
    const aligned_used = used_bytes + padding;
    if (size > heap_total_bytes - aligned_used) {
        overflow_count += 1;
        last_alloc_ok = false;
        last_error = .out_of_memory;
        return null;
    }

    used_bytes = aligned_used + size;
    alloc_count += 1;
    last_alloc_ok = true;
    last_error = .none;
    return @ptrFromInt(aligned);
}

pub fn reset() void {
    used_bytes = 0;
    reset_count += 1;
    last_alloc_size = 0;
    last_alloc_ok = false;
    last_error = .none;
}

pub fn stats() Stats {
    return .{
        .total_bytes = heap_total_bytes,
        .used_bytes = used_bytes,
        .free_bytes = heap_total_bytes - used_bytes,
        .alloc_count = alloc_count,
        .reset_count = reset_count,
        .overflow_count = overflow_count,
        .last_alloc_size = last_alloc_size,
        .last_alloc_ok = last_alloc_ok,
        .last_error = last_error,
    };
}

pub fn selfTest() bool {
    reset();
    const before = stats();
    if (before.used_bytes != 0) return false;
    if (alloc(64, 8) == null) return false;
    const after_alloc = stats();
    if (after_alloc.used_bytes != 64) return false;
    reset();
    const after_reset = stats();
    if (after_reset.used_bytes != 0) return false;
    const before_overflow = stats();
    if (alloc(heap_total_bytes + 1, 8) != null) return false;
    const after_overflow = stats();
    if (after_overflow.used_bytes != before_overflow.used_bytes) return false;
    if (after_overflow.last_error != .out_of_memory) return false;
    return true;
}

pub fn printHeap() void {
    const s = stats();
    uart.write("heap: interface=present\r\n");
    uart.write("heap: kind=");
    uart.write(heap_kind);
    uart.write("\r\n");
    uart.write("heap: total_bytes=");
    uart.writeDec(s.total_bytes);
    uart.write("\r\n");
    uart.write("heap: used_bytes=");
    uart.writeDec(s.used_bytes);
    uart.write("\r\n");
    uart.write("heap: free_bytes=");
    uart.writeDec(s.free_bytes);
    uart.write("\r\n");
    uart.write("heap: alloc_count=");
    uart.writeDec(s.alloc_count);
    uart.write("\r\n");
    uart.write("heap: reset_count=");
    uart.writeDec(s.reset_count);
    uart.write("\r\n");
    uart.write("heap: overflow_count=");
    uart.writeDec(s.overflow_count);
    uart.write("\r\n");
    uart.write("heap: last_alloc_ok=");
    uart.write(okString(s.last_alloc_ok));
    uart.write("\r\n");
    uart.write("heap: last_error=");
    uart.write(errorString(s.last_error));
    uart.write("\r\n");
    uart.write("heap: free_individual_blocks=not-implemented\r\n");
    uart.write("heap: thread_safe=not-implemented\r\n");
    uart.write("heap: userspace_allocator=not-implemented\r\n");
}

pub fn printStats() void {
    const s = stats();
    uart.write("heap-stats: total_bytes=");
    uart.writeDec(s.total_bytes);
    uart.write("\r\n");
    uart.write("heap-stats: used_bytes=");
    uart.writeDec(s.used_bytes);
    uart.write("\r\n");
    uart.write("heap-stats: free_bytes=");
    uart.writeDec(s.free_bytes);
    uart.write("\r\n");
    uart.write("heap-stats: alloc_count=");
    uart.writeDec(s.alloc_count);
    uart.write("\r\n");
    uart.write("heap-stats: reset_count=");
    uart.writeDec(s.reset_count);
    uart.write("\r\n");
    uart.write("heap-stats: overflow_count=");
    uart.writeDec(s.overflow_count);
    uart.write("\r\n");
}

pub fn printAllocTest() void {
    reset();
    const before = stats();
    _ = alloc(64, 8);
    const after = stats();
    const pass = before.used_bytes == 0 and after.used_bytes == 64 and after.alloc_count == before.alloc_count + 1 and after.last_alloc_ok and after.last_error == .none;

    uart.write("heap-alloc-test: begin\r\n");
    uart.write("heap_used_before=");
    uart.writeDec(before.used_bytes);
    uart.write("\r\n");
    uart.write("heap_alloc_size=64\r\n");
    uart.write("heap_alloc_alignment=8\r\n");
    uart.write("heap_alloc_ok=");
    uart.write(okString(after.last_alloc_ok));
    uart.write("\r\n");
    uart.write("heap_used_after_alloc=");
    uart.writeDec(after.used_bytes);
    uart.write("\r\n");
    uart.write("heap_alloc_count_after=");
    uart.writeDec(after.alloc_count - before.alloc_count);
    uart.write("\r\n");
    uart.write("heap_last_error=");
    uart.write(errorString(after.last_error));
    uart.write("\r\n");
    uart.write("heap-alloc-test: result=");
    uart.write(if (pass) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printResetTest() void {
    reset();
    _ = alloc(64, 8);
    const before = stats();
    reset();
    const after = stats();
    const pass = before.used_bytes != 0 and after.used_bytes == 0;

    uart.write("heap-reset-test: begin\r\n");
    uart.write("heap_used_before_reset=");
    uart.writeDec(before.used_bytes);
    uart.write("\r\n");
    uart.write("heap_reset=ok\r\n");
    uart.write("heap_used_after_reset=");
    uart.writeDec(after.used_bytes);
    uart.write("\r\n");
    uart.write("heap-reset-test: result=");
    uart.write(if (pass) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printOverflowTest() void {
    reset();
    const before = stats();
    const request = heap_total_bytes + 1;
    const rejected = alloc(request, 8) == null;
    const after = stats();
    const pass = before.used_bytes == 0 and rejected and after.used_bytes == before.used_bytes and after.last_error == .out_of_memory;

    uart.write("heap-overflow-test: begin\r\n");
    uart.write("heap_overflow_request_bytes=");
    uart.writeDec(request);
    uart.write("\r\n");
    uart.write("heap_used_before_overflow=");
    uart.writeDec(before.used_bytes);
    uart.write("\r\n");
    uart.write("heap_overflow_rejected=");
    uart.write(if (rejected) "yes" else "no");
    uart.write("\r\n");
    uart.write("heap_used_after_overflow=");
    uart.writeDec(after.used_bytes);
    uart.write("\r\n");
    uart.write("heap_last_error=");
    uart.write(errorString(after.last_error));
    uart.write("\r\n");
    uart.write("heap-overflow-test: result=");
    uart.write(if (pass) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printStatusFields() void {
    const s = stats();
    uart.write("heap_interface=present\r\n");
    uart.write("heap_kind=");
    uart.write(heap_kind);
    uart.write("\r\n");
    uart.write("heap_total_bytes=");
    uart.writeDec(s.total_bytes);
    uart.write("\r\n");
    uart.write("heap_used_bytes=");
    uart.writeDec(s.used_bytes);
    uart.write("\r\n");
    uart.write("heap_free_bytes=");
    uart.writeDec(s.free_bytes);
    uart.write("\r\n");
    uart.write("heap_alloc_count=");
    uart.writeDec(s.alloc_count);
    uart.write("\r\n");
    uart.write("heap_reset_count=");
    uart.writeDec(s.reset_count);
    uart.write("\r\n");
    uart.write("heap_overflow_count=");
    uart.writeDec(s.overflow_count);
    uart.write("\r\n");
    uart.write("heap_last_alloc_size=");
    uart.writeDec(s.last_alloc_size);
    uart.write("\r\n");
    uart.write("heap_last_alloc_ok=");
    uart.write(okString(s.last_alloc_ok));
    uart.write("\r\n");
    uart.write("heap_last_error=");
    uart.write(errorString(s.last_error));
    uart.write("\r\n");
}

pub fn errorString(err: Error) []const u8 {
    return switch (err) {
        .none => "none",
        .out_of_memory => "out-of-memory",
        .invalid_size => "invalid-size",
        .invalid_alignment => "invalid-alignment",
    };
}

fn okString(ok: bool) []const u8 {
    return if (ok) "yes" else "no";
}

fn validAlignment(alignment: usize) bool {
    return alignment != 0 and (alignment & (alignment - 1)) == 0;
}

fn alignForward(value: usize, alignment: usize) ?usize {
    const mask = alignment - 1;
    const max = ~@as(usize, 0);
    if (value > max - mask) return null;
    return (value + mask) & ~mask;
}

pub fn heap_init() void {
    init();
}

pub fn heap_alloc(size: usize, alignment: usize) ?[*]u8 {
    return alloc(size, alignment);
}

pub fn heap_reset() void {
    reset();
}

pub fn heap_stats() Stats {
    return stats();
}

pub fn heap_self_test() bool {
    return selfTest();
}
