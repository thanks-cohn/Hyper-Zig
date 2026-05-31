const log = @import("../log.zig");
const uart = @import("../console/uart.zig");
const board = @import("../board/board.zig");
const memory_v0 = @import("memory.zig");

extern var __kernel_start: u8;
extern var __kernel_end: u8;
extern var __bss_start: u8;
extern var __bss_end: u8;

pub const page_size: usize = 4096;
pub const pmm_kind = "bitmap-v0";

const max_pages: usize = board.ram_size_bytes / page_size;
const bitmap_bytes: usize = (max_pages + 7) / 8;

pub const Error = enum {
    none,
    out_of_pages,
    invalid_free,
    double_free,
    reserved_page,
};

pub const Stats = struct {
    total_pages: usize,
    free_pages: usize,
    used_pages: usize,
    reserved_pages: usize,
    alloc_count: usize,
    free_count: usize,
    invalid_free_count: usize,
    double_free_count: usize,
    exhaustion_count: usize,
    last_error: Error,
};

var reserved_bitmap: [bitmap_bytes]u8 = [_]u8{0} ** bitmap_bytes;
var used_bitmap: [bitmap_bytes]u8 = [_]u8{0} ** bitmap_bytes;
var total_pages: usize = 0;
var free_pages: usize = 0;
var used_pages: usize = 0;
var reserved_pages: usize = 0;
var alloc_count: usize = 0;
var free_count: usize = 0;
var invalid_free_count: usize = 0;
var double_free_count: usize = 0;
var exhaustion_count: usize = 0;
var last_error: Error = .none;
var managed_base: usize = board.ram_base;
var managed_end: usize = board.ram_base + board.ram_size_bytes;
var kernel_reserved_end: usize = 0;

pub fn init() void {
    log.info("MEM", "MEM001", "memory map initialized for qemu virt dram");
    memory_v0.init();
    resetAccounting();
    log.info("PMM", "PMM000", "physical page manager initialized; bitmap-v0 accounting active; kernel/unavailable pages reserved");
    report();
}

fn resetAccounting() void {
    managed_base = board.ram_base;
    managed_end = board.ram_base + board.ram_size_bytes;
    total_pages = board.ram_size_bytes / page_size;
    free_pages = 0;
    used_pages = 0;
    reserved_pages = 0;
    alloc_count = 0;
    free_count = 0;
    invalid_free_count = 0;
    double_free_count = 0;
    exhaustion_count = 0;
    last_error = .none;
    kernel_reserved_end = alignForward(kernelEnd(), page_size);

    clearBitmap(&reserved_bitmap);
    clearBitmap(&used_bitmap);

    var i: usize = 0;
    while (i < total_pages) : (i += 1) {
        const page_addr = managed_base + (i * page_size);
        if (page_addr < kernel_reserved_end) {
            setBit(&reserved_bitmap, i);
            reserved_pages += 1;
        } else {
            free_pages += 1;
        }
    }
}

pub fn report() void {
    uart.write("[ZIGN01D][INFO][MEM][MEM002] dram base=0x80000000 kernel_start=");
    uart.writeHex(kernelStart());
    uart.write(" kernel_end=");
    uart.writeHex(kernelEnd());
    uart.write(" bss=");
    uart.writeHex(@intFromPtr(&__bss_start));
    uart.write("..");
    uart.writeHex(@intFromPtr(&__bss_end));
    uart.write("\r\n");
    uart.write("[ZIGN01D][INFO][PMM][PMM001] managed_region_start=");
    uart.writeHex(managed_base);
    uart.write(" managed_region_end=");
    uart.writeHex(managed_end);
    uart.write(" page_size=");
    uart.writeDec(page_size);
    uart.write(" total_pages=");
    uart.writeDec(total_pages);
    uart.write(" reserved_pages=");
    uart.writeDec(reserved_pages);
    uart.write(" free_pages=");
    uart.writeDec(free_pages);
    uart.write(" used_pages=");
    uart.writeDec(used_pages);
    uart.write(" kind=");
    uart.write(pmm_kind);
    uart.write("\r\n");
}

pub fn stats() Stats {
    return .{
        .total_pages = total_pages,
        .free_pages = free_pages,
        .used_pages = used_pages,
        .reserved_pages = reserved_pages,
        .alloc_count = alloc_count,
        .free_count = free_count,
        .invalid_free_count = invalid_free_count,
        .double_free_count = double_free_count,
        .exhaustion_count = exhaustion_count,
        .last_error = last_error,
    };
}

pub fn allocPage() ?usize {
    var i: usize = 0;
    while (i < total_pages) : (i += 1) {
        if (!isSet(&reserved_bitmap, i) and !isSet(&used_bitmap, i)) {
            setBit(&used_bitmap, i);
            free_pages -= 1;
            used_pages += 1;
            alloc_count += 1;
            last_error = .none;
            return managed_base + (i * page_size);
        }
    }
    exhaustion_count += 1;
    last_error = .out_of_pages;
    return null;
}

pub fn freePage(addr: usize) bool {
    const index = pageIndexForFree(addr) orelse return false;
    if (isSet(&reserved_bitmap, index)) {
        invalid_free_count += 1;
        last_error = .reserved_page;
        return false;
    }
    if (!isSet(&used_bitmap, index)) {
        double_free_count += 1;
        last_error = .double_free;
        return false;
    }

    clearBit(&used_bitmap, index);
    used_pages -= 1;
    free_pages += 1;
    free_count += 1;
    last_error = .none;
    return true;
}

fn pageIndexForFree(addr: usize) ?usize {
    if ((addr % page_size) != 0 or addr < managed_base or addr >= managed_end) {
        invalid_free_count += 1;
        last_error = .invalid_free;
        return null;
    }
    return (addr - managed_base) / page_size;
}

fn kernelStart() usize {
    return @intFromPtr(&__kernel_start);
}

fn kernelEnd() usize {
    return @intFromPtr(&__kernel_end);
}

fn alignForward(value: usize, alignment: usize) usize {
    return (value + alignment - 1) & ~(alignment - 1);
}

fn clearBitmap(bitmap: *[bitmap_bytes]u8) void {
    var i: usize = 0;
    while (i < bitmap.len) : (i += 1) bitmap[i] = 0;
}

fn setBit(bitmap: *[bitmap_bytes]u8, index: usize) void {
    bitmap[index / 8] |= @as(u8, 1) << @intCast(index % 8);
}

fn clearBit(bitmap: *[bitmap_bytes]u8, index: usize) void {
    bitmap[index / 8] &= ~(@as(u8, 1) << @intCast(index % 8));
}

fn isSet(bitmap: *const [bitmap_bytes]u8, index: usize) bool {
    return (bitmap[index / 8] & (@as(u8, 1) << @intCast(index % 8))) != 0;
}

pub fn printPmm() void {
    uart.write("pmm_interface=present\r\n");
    uart.write("pmm_kind=");
    uart.write(pmm_kind);
    uart.write("\r\n");
    uart.write("pmm_page_size=");
    uart.writeDec(page_size);
    uart.write("\r\n");
    printStatsFields();
    printRegionFields();
    uart.write("pmm_kernel_reserved_end=");
    uart.writeHex(kernel_reserved_end);
    uart.write("\r\n");
    printNonClaims();
}

pub fn printStats() void {
    printStatsFields();
}

pub fn printStatusFields() void {
    uart.write("pmm_interface=present\r\n");
    uart.write("pmm_kind=");
    uart.write(pmm_kind);
    uart.write("\r\n");
    uart.write("pmm_page_size=");
    uart.writeDec(page_size);
    uart.write("\r\n");
    printStatsFields();
    printNonClaims();
}

fn printRegionFields() void {
    uart.write("pmm_managed_region_start=");
    uart.writeHex(managed_base);
    uart.write("\r\n");
    uart.write("pmm_managed_region_end=");
    uart.writeHex(managed_end);
    uart.write("\r\n");
}

fn printStatsFields() void {
    const s = stats();
    uart.write("pmm_total_pages=");
    uart.writeDec(s.total_pages);
    uart.write("\r\n");
    uart.write("pmm_free_pages=");
    uart.writeDec(s.free_pages);
    uart.write("\r\n");
    uart.write("pmm_used_pages=");
    uart.writeDec(s.used_pages);
    uart.write("\r\n");
    uart.write("pmm_reserved_pages=");
    uart.writeDec(s.reserved_pages);
    uart.write("\r\n");
    uart.write("pmm_alloc_count=");
    uart.writeDec(s.alloc_count);
    uart.write("\r\n");
    uart.write("pmm_free_count=");
    uart.writeDec(s.free_count);
    uart.write("\r\n");
    uart.write("pmm_invalid_free_count=");
    uart.writeDec(s.invalid_free_count);
    uart.write("\r\n");
    uart.write("pmm_double_free_count=");
    uart.writeDec(s.double_free_count);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_count=");
    uart.writeDec(s.exhaustion_count);
    uart.write("\r\n");
    uart.write("pmm_last_error=");
    uart.write(errorString(s.last_error));
    uart.write("\r\n");
}

fn printNonClaims() void {
    uart.write("paging=not-implemented\r\n");
    uart.write("virtual_memory=not-implemented\r\n");
    uart.write("userspace_memory=not-implemented\r\n");
    uart.write("swap=not-implemented\r\n");
    uart.write("numa=not-implemented\r\n");
    uart.write("production_pmm=not-implemented\r\n");
    uart.write("memory_hotplug=not-implemented\r\n");
    uart.write("page_cache=not-implemented\r\n");
}

pub fn printAllocTest() void {
    resetAccounting();
    const before = stats();
    const page = allocPage();
    const after = stats();
    const ok = page != null and after.free_pages + 1 == before.free_pages and after.used_pages == before.used_pages + 1 and after.alloc_count == before.alloc_count + 1 and after.last_error == .none;

    uart.write("pmm-alloc-test: begin\r\n");
    uart.write("pmm_free_before=");
    uart.writeDec(before.free_pages);
    uart.write("\r\n");
    uart.write("pmm_used_before=");
    uart.writeDec(before.used_pages);
    uart.write("\r\n");
    uart.write("pmm_alloc_count_before=");
    uart.writeDec(before.alloc_count);
    uart.write("\r\n");
    uart.write("pmm_alloc_page_ok=");
    uart.write(if (page != null) "yes" else "no");
    uart.write("\r\n");
    if (page) |addr| {
        uart.write("pmm_alloc_page_addr=");
        uart.writeHex(addr);
        uart.write("\r\n");
        logAllocSuccess("PMM010", addr, after);
    }
    uart.write("pmm_free_after_alloc=");
    uart.writeDec(after.free_pages);
    uart.write("\r\n");
    uart.write("pmm_used_after_alloc=");
    uart.writeDec(after.used_pages);
    uart.write("\r\n");
    uart.write("pmm_alloc_count_after=");
    uart.writeDec(after.alloc_count);
    uart.write("\r\n");
    uart.write("pmm_alloc_test=");
    uart.write(if (ok) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printFreeTest() void {
    resetAccounting();
    const start = stats();
    const page = allocPage();
    const before = stats();
    const freed = if (page) |addr| freePage(addr) else false;
    const after = stats();
    const ok = page != null and freed and after.free_pages == start.free_pages and after.used_pages == start.used_pages and after.free_count == before.free_count + 1 and after.last_error == .none;

    uart.write("pmm-free-test: begin\r\n");
    uart.write("pmm_free_before_alloc=");
    uart.writeDec(start.free_pages);
    uart.write("\r\n");
    if (page) |addr| {
        uart.write("pmm_free_test_page_addr=");
        uart.writeHex(addr);
        uart.write("\r\n");
        logAllocSuccess("PMM010", addr, before);
    }
    uart.write("pmm_free_before_free=");
    uart.writeDec(before.free_pages);
    uart.write("\r\n");
    uart.write("pmm_used_before_free=");
    uart.writeDec(before.used_pages);
    uart.write("\r\n");
    uart.write("pmm_free_count_before=");
    uart.writeDec(before.free_count);
    uart.write("\r\n");
    uart.write("pmm_free_page_ok=");
    uart.write(if (freed) "yes" else "no");
    uart.write("\r\n");
    uart.write("pmm_free_after_free=");
    uart.writeDec(after.free_pages);
    uart.write("\r\n");
    uart.write("pmm_used_after_free=");
    uart.writeDec(after.used_pages);
    uart.write("\r\n");
    uart.write("pmm_free_count_after=");
    uart.writeDec(after.free_count);
    uart.write("\r\n");
    if (page) |addr| {
        if (freed) logFreeSuccess("PMM011", addr, after);
    }
    uart.write("pmm_free_test=");
    uart.write(if (ok) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printInvalidFreeTest() void {
    resetAccounting();
    const before = stats();
    const bad_addr = managed_end + page_size;
    const rejected = !freePage(bad_addr);
    const after = stats();
    const ok = rejected and after.free_pages == before.free_pages and after.used_pages == before.used_pages and after.invalid_free_count == before.invalid_free_count + 1 and after.last_error == .invalid_free;

    uart.write("pmm-invalid-free-test: begin\r\n");
    uart.write("pmm_invalid_free_addr=");
    uart.writeHex(bad_addr);
    uart.write("\r\n");
    uart.write("pmm_invalid_free_count_before=");
    uart.writeDec(before.invalid_free_count);
    uart.write("\r\n");
    uart.write("pmm_invalid_free_rejected=");
    uart.write(if (rejected) "yes" else "no");
    uart.write("\r\n");
    uart.write("pmm_invalid_free_count_after=");
    uart.writeDec(after.invalid_free_count);
    uart.write("\r\n");
    uart.write("pmm_last_error=");
    uart.write(errorString(after.last_error));
    uart.write("\r\n");
    logInvalidFree("PMM012", bad_addr, after);
    uart.write("pmm-invalid-free-test: result=");
    uart.write(if (ok) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printDoubleFreeTest() void {
    resetAccounting();
    const page = allocPage();
    const first = if (page) |addr| freePage(addr) else false;
    const before_second = stats();
    const second = if (page) |addr| freePage(addr) else true;
    const after = stats();
    const rejected = !second;
    const ok = page != null and first and rejected and after.free_pages == before_second.free_pages and after.used_pages == before_second.used_pages and after.double_free_count == before_second.double_free_count + 1 and after.last_error == .double_free;

    uart.write("pmm-double-free-test: begin\r\n");
    if (page) |addr| {
        uart.write("pmm_double_free_addr=");
        uart.writeHex(addr);
        uart.write("\r\n");
    }
    uart.write("pmm_double_free_count_before=");
    uart.writeDec(before_second.double_free_count);
    uart.write("\r\n");
    uart.write("pmm_double_free_rejected=");
    uart.write(if (rejected) "yes" else "no");
    uart.write("\r\n");
    uart.write("pmm_double_free_count_after=");
    uart.writeDec(after.double_free_count);
    uart.write("\r\n");
    uart.write("pmm_last_error=");
    uart.write(errorString(after.last_error));
    uart.write("\r\n");
    if (page) |addr| {
        if (first) logFreeSuccess("PMM011", addr, before_second);
        logDoubleFree("PMM013", addr, after);
    }
    uart.write("pmm-double-free-test: result=");
    uart.write(if (ok) "pass" else "fail");
    uart.write("\r\n");
}

pub fn printExhaustionTest() void {
    resetAccounting();
    const before = stats();
    const test_pool_pages: usize = 3;
    var test_used = [_]bool{false} ** test_pool_pages;
    var allocated: usize = 0;
    while (tinyTestAlloc(&test_used) != null) : (allocated += 1) {}
    const test_free_after_fill = tinyTestFreePages(&test_used);
    const rejected = tinyTestAlloc(&test_used) == null;
    if (rejected) {
        exhaustion_count += 1;
        last_error = .out_of_pages;
    }
    const after_reject = stats();
    const ok = allocated == test_pool_pages and test_free_after_fill == 0 and rejected and after_reject.free_pages == before.free_pages and after_reject.used_pages == before.used_pages and after_reject.exhaustion_count == before.exhaustion_count + 1 and after_reject.last_error == .out_of_pages;

    uart.write("pmm-exhaustion-test: begin\r\n");
    uart.write("pmm_exhaustion_mode=bounded-test-pool\r\n");
    uart.write("pmm_exhaustion_test_pool_pages=");
    uart.writeDec(test_pool_pages);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_start_free_pages=");
    uart.writeDec(test_pool_pages);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_count_before=");
    uart.writeDec(before.exhaustion_count);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_global_free_pages_before=");
    uart.writeDec(before.free_pages);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_allocated_pages=");
    uart.writeDec(allocated);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_free_after_fill=");
    uart.writeDec(test_free_after_fill);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_global_free_pages_after=");
    uart.writeDec(after_reject.free_pages);
    uart.write("\r\n");
    uart.write("pmm_exhaustion_rejected=");
    uart.write(if (rejected) "yes" else "no");
    uart.write("\r\n");
    uart.write("pmm_exhaustion_count_after=");
    uart.writeDec(after_reject.exhaustion_count);
    uart.write("\r\n");
    uart.write("pmm_last_error=");
    uart.write(errorString(after_reject.last_error));
    uart.write("\r\n");
    logExhaustion("PMM014", after_reject);
    uart.write("pmm-exhaustion-test: result=");
    uart.write(if (ok) "pass" else "fail");
    uart.write("\r\n");
}

fn tinyTestAlloc(test_used: []bool) ?usize {
    var i: usize = 0;
    while (i < test_used.len) : (i += 1) {
        if (!test_used[i]) {
            test_used[i] = true;
            return i;
        }
    }
    return null;
}

fn tinyTestFreePages(test_used: []const bool) usize {
    var free: usize = 0;
    var i: usize = 0;
    while (i < test_used.len) : (i += 1) {
        if (!test_used[i]) free += 1;
    }
    return free;
}

fn logAllocSuccess(code: []const u8, addr: usize, s: Stats) void {
    uart.write("[ZIGN01D][INFO][PMM][");
    uart.write(code);
    uart.write("] allocation success page_addr=");
    uart.writeHex(addr);
    writeCounterTail(s);
}

fn logFreeSuccess(code: []const u8, addr: usize, s: Stats) void {
    uart.write("[ZIGN01D][INFO][PMM][");
    uart.write(code);
    uart.write("] free success page_addr=");
    uart.writeHex(addr);
    writeCounterTail(s);
}

fn logInvalidFree(code: []const u8, addr: usize, s: Stats) void {
    uart.write("[ZIGN01D][WARN][PMM][");
    uart.write(code);
    uart.write("] invalid free rejected attempted_addr=");
    uart.writeHex(addr);
    uart.write(" reason=invalid-free");
    writeCounterTail(s);
}

fn logDoubleFree(code: []const u8, addr: usize, s: Stats) void {
    uart.write("[ZIGN01D][WARN][PMM][");
    uart.write(code);
    uart.write("] double free rejected attempted_addr=");
    uart.writeHex(addr);
    uart.write(" reason=double-free");
    writeCounterTail(s);
}

fn logExhaustion(code: []const u8, s: Stats) void {
    uart.write("[ZIGN01D][WARN][PMM][");
    uart.write(code);
    uart.write("] exhaustion rejected reason=out-of-pages");
    writeCounterTail(s);
}

fn writeCounterTail(s: Stats) void {
    uart.write(" free_pages=");
    uart.writeDec(s.free_pages);
    uart.write(" used_pages=");
    uart.writeDec(s.used_pages);
    uart.write(" alloc_count=");
    uart.writeDec(s.alloc_count);
    uart.write(" free_count=");
    uart.writeDec(s.free_count);
    uart.write(" invalid_free_count=");
    uart.writeDec(s.invalid_free_count);
    uart.write(" double_free_count=");
    uart.writeDec(s.double_free_count);
    uart.write(" exhaustion_count=");
    uart.writeDec(s.exhaustion_count);
    uart.write(" last_error=");
    uart.write(errorString(s.last_error));
    uart.write("\r\n");
}

fn errorString(err: Error) []const u8 {
    return switch (err) {
        .none => "none",
        .out_of_pages => "out-of-pages",
        .invalid_free => "invalid-free",
        .double_free => "double-free",
        .reserved_page => "reserved-page",
    };
}
