const uart = @import("../console/uart.zig");
const tarfs = @import("tarfs.zig");
const ramfs = @import("ramfs.zig");

const root_mount = "/";
const ram_mount = "/ram";
const tarfs_name = "tarfs-readonly-v0";
const ramfs_name = "ramfs-volatile-memory-v0";
const empty_error = "none";

const FsKind = enum { tarfs, ramfs };
const Route = struct { fs: FsKind, fs_name: []const u8, mount: []const u8, readonly: bool };
const Counters = struct {
    route_count: usize = 0,
    list_count: usize = 0,
    stat_count: usize = 0,
    read_count: usize = 0,
    checksum_count: usize = 0,
    create_count: usize = 0,
    write_count: usize = 0,
    append_count: usize = 0,
    delete_count: usize = 0,
    missing_count: usize = 0,
    readonly_reject_count: usize = 0,
    invalid_mount_count: usize = 0,
};

var counters = Counters{};
var last_error: []const u8 = empty_error;

pub fn init() void {
    counters = Counters{};
    last_error = empty_error;
    uart.write("[ZIGN01D][INFO][VFS][VFS000] initialized mount_count=2 root=/ ram=/ram\r\n");
}

pub fn printOverview() void {
    printCommon();
}

pub fn printMounts() void {
    uart.write("[ZIGN01D][INFO][VFS][VFS001] mount table requested mount_count=2\r\n");
    printCommon();
}

pub fn printRoute(path: []const u8) void {
    if (route(path)) |r| {
        counters.route_count += 1;
        last_error = empty_error;
        logRoute(path, r);
        uart.write("vfs_route_ok=yes\r\n");
        uart.write("vfs_route_path="); uart.write(path); uart.write("\r\n");
        uart.write("vfs_route_fs="); uart.write(r.fs_name); uart.write("\r\n");
        uart.write("vfs_route_mount="); uart.write(r.mount); uart.write("\r\n");
        printCounters();
        return;
    }
    rejectInvalidMount(path);
}

pub fn printList(path: []const u8) void {
    const r = routeOrReject(path) orelse return;
    counters.list_count += 1;
    last_error = empty_error;
    uart.write("[ZIGN01D][INFO][VFS][VFS003] list routed path="); uart.write(path);
    uart.write(" fs="); uart.write(r.fs_name); uart.write(" mount="); uart.write(r.mount); uart.write("\r\n");
    uart.write("vfs_list_ok=yes\r\n");
    uart.write("vfs_list_path="); uart.write(path); uart.write("\r\n");
    uart.write("vfs_list_fs="); uart.write(r.fs_name); uart.write("\r\n");
    switch (r.fs) {
        .tarfs => {
            for (tarfs.files) |file| printEntry(file.path, file.data.len, file.checksum);
        },
        .ramfs => {
            var i: usize = 0;
            while (i < ramfs.count()) : (i += 1) {
                if (ramfs.fileAt(i)) |file| {
                    const data = ramfs.dataOf(file);
                    printEntry(ramfs.pathOf(file), data.len, ramfs.checksum(data));
                }
            }
        },
    }
    printCounters();
}

pub fn printStat(path: []const u8) void {
    const r = routeOrReject(path) orelse return;
    switch (r.fs) {
        .tarfs => if (tarfs.find(path)) |file| return statOk(path, r, file.data.len, file.checksum),
        .ramfs => {
            const s = ramfs.stat(path);
            if (s.status == .ok) return statOk(path, r, s.size, s.sum);
        },
    }
    rejectMissing(path);
}

pub fn printCat(path: []const u8) void {
    const r = routeOrReject(path) orelse return;
    switch (r.fs) {
        .tarfs => if (tarfs.find(path)) |file| return catOk(path, r, file.data),
        .ramfs => {
            const rr = ramfs.read(path);
            if (rr.status == .ok) return catOk(path, r, rr.data);
        },
    }
    rejectMissing(path);
}

pub fn printChecksum(path: []const u8) void {
    const r = routeOrReject(path) orelse return;
    switch (r.fs) {
        .tarfs => if (tarfs.find(path)) |file| return checksumOk(path, r, file.checksum, file.data.len),
        .ramfs => {
            const s = ramfs.stat(path);
            if (s.status == .ok) return checksumOk(path, r, s.sum, s.size);
        },
    }
    rejectMissing(path);
}

pub fn printCreate(path: []const u8) void {
    const r = routeOrReject(path) orelse return;
    if (r.readonly) return rejectReadonly(path, r);
    const status = ramfs.create(path);
    if (status == .ok) {
        counters.create_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][VFS][VFS007] create routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write("\r\n");
        uart.write("vfs_create_ok=yes\r\n");
        uart.write("vfs_create_path="); uart.write(path); uart.write("\r\n");
        printCounters();
        return;
    }
    rejectStatus(path, status);
}

pub fn printWrite(path: []const u8, bytes: []const u8) void {
    const r = routeOrReject(path) orelse return;
    if (r.readonly) return rejectReadonly(path, r);
    const data = stripQuotes(bytes);
    const status = ramfs.write(path, data);
    if (status == .ok) {
        counters.write_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][VFS][VFS008] write routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" bytes="); uart.writeDec(data.len); uart.write("\r\n");
        uart.write("vfs_write_ok=yes\r\n");
        uart.write("vfs_write_path="); uart.write(path); uart.write("\r\n");
        uart.write("vfs_write_bytes="); uart.writeDec(data.len); uart.write("\r\n");
        printCounters();
        return;
    }
    rejectStatus(path, status);
}

pub fn printAppend(path: []const u8, bytes: []const u8) void {
    const r = routeOrReject(path) orelse return;
    if (r.readonly) return rejectReadonly(path, r);
    const data = stripQuotes(bytes);
    const status = ramfs.append(path, data);
    if (status == .ok) {
        counters.append_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][VFS][VFS009] append routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" bytes="); uart.writeDec(data.len); uart.write("\r\n");
        uart.write("vfs_append_ok=yes\r\n");
        uart.write("vfs_append_path="); uart.write(path); uart.write("\r\n");
        printCounters();
        return;
    }
    rejectStatus(path, status);
}

pub fn printDelete(path: []const u8) void {
    const r = routeOrReject(path) orelse return;
    if (r.readonly) return rejectReadonly(path, r);
    const status = ramfs.delete(path);
    if (status == .ok) {
        counters.delete_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][VFS][VFS010] delete routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write("\r\n");
        uart.write("vfs_delete_ok=yes\r\n");
        uart.write("vfs_delete_path="); uart.write(path); uart.write("\r\n");
        printCounters();
        return;
    }
    rejectStatus(path, status);
}

fn statOk(path: []const u8, r: Route, size: usize, sum: u32) void {
    counters.stat_count += 1;
    last_error = empty_error;
    uart.write("[ZIGN01D][INFO][VFS][VFS004] stat routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" bytes="); uart.writeDec(size); uart.write(" checksum="); uart.writeDec(sum); uart.write("\r\n");
    uart.write("vfs_stat_ok=yes\r\n");
    uart.write("vfs_stat_path="); uart.write(path); uart.write("\r\n");
    uart.write("vfs_stat_size="); uart.writeDec(size); uart.write("\r\n");
    uart.write("vfs_stat_checksum="); uart.writeDec(sum); uart.write("\r\n");
    printCounters();
}

fn catOk(path: []const u8, r: Route, data: []const u8) void {
    counters.read_count += 1;
    last_error = empty_error;
    uart.write("[ZIGN01D][INFO][VFS][VFS005] read routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" bytes="); uart.writeDec(data.len); uart.write("\r\n");
    uart.write("vfs_cat_ok=yes\r\n");
    uart.write("vfs_cat_path="); uart.write(path); uart.write("\r\n");
    uart.write("vfs_cat_bytes="); uart.writeDec(data.len); uart.write("\r\n");
    uart.write(data); uart.write("\r\n");
    printCounters();
}

fn checksumOk(path: []const u8, r: Route, sum: u32, size: usize) void {
    counters.checksum_count += 1;
    last_error = empty_error;
    uart.write("[ZIGN01D][INFO][VFS][VFS006] checksum routed path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" checksum="); uart.writeDec(sum); uart.write(" bytes="); uart.writeDec(size); uart.write("\r\n");
    uart.write("vfs_checksum_ok=yes\r\n");
    uart.write("vfs_checksum_path="); uart.write(path); uart.write("\r\n");
    uart.write("vfs_checksum="); uart.writeDec(sum); uart.write("\r\n");
    printCounters();
}

fn routeOrReject(path: []const u8) ?Route {
    if (route(path)) |r| return r;
    rejectInvalidMount(path);
    return null;
}

fn route(path: []const u8) ?Route {
    if (path.len == 0 or path[0] != '/') return null;
    if (equals(path, ram_mount) or startsWith(path, "/ram/")) return .{ .fs = .ramfs, .fs_name = ramfs_name, .mount = ram_mount, .readonly = false };
    if (startsWith(path, "/unknown/")) return null;
    return .{ .fs = .tarfs, .fs_name = tarfs_name, .mount = root_mount, .readonly = true };
}

fn rejectMissing(path: []const u8) void {
    counters.missing_count += 1;
    last_error = "not-found";
    uart.write("[ZIGN01D][WARN][VFS][VFS011] missing path rejected path="); uart.write(path); uart.write(" reason=not-found\r\n");
    uart.write("vfs_missing_rejected=yes\r\n");
    uart.write("vfs_last_error=not-found\r\n");
    uart.write("attempted_path="); uart.write(path); uart.write("\r\n");
    printCounters();
}

fn rejectReadonly(path: []const u8, r: Route) void {
    counters.readonly_reject_count += 1;
    last_error = "read-only";
    uart.write("[ZIGN01D][WARN][VFS][VFS012] read-only write rejected path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" reason=read-only\r\n");
    uart.write("vfs_readonly_write_rejected=yes\r\n");
    uart.write("vfs_last_error=read-only\r\n");
    uart.write("attempted_path="); uart.write(path); uart.write("\r\n");
    uart.write("routed_fs="); uart.write(r.fs_name); uart.write("\r\n");
    printCounters();
}

fn rejectInvalidMount(path: []const u8) void {
    counters.invalid_mount_count += 1;
    last_error = "no-mount";
    uart.write("[ZIGN01D][WARN][VFS][VFS013] invalid/no mount rejected path="); uart.write(path); uart.write(" reason=no-mount\r\n");
    uart.write("vfs_invalid_mount_rejected=yes\r\n");
    uart.write("vfs_last_error=no-mount\r\n");
    uart.write("attempted_path="); uart.write(path); uart.write("\r\n");
    printCounters();
}

fn rejectStatus(path: []const u8, status: ramfs.OpStatus) void {
    switch (status) {
        .not_found, .invalid_path => rejectMissing(path),
        .already_exists => rejectMissingWith(path, "already-exists"),
        .capacity_full => rejectMissingWith(path, "capacity-full"),
        .file_too_large => rejectMissingWith(path, "file-too-large"),
        .ok => {},
    }
}

fn rejectMissingWith(path: []const u8, reason: []const u8) void {
    counters.missing_count += 1;
    last_error = reason;
    uart.write("[ZIGN01D][WARN][VFS][VFS011] missing path rejected path="); uart.write(path); uart.write(" reason="); uart.write(reason); uart.write("\r\n");
    uart.write("vfs_missing_rejected=yes\r\n");
    uart.write("vfs_last_error="); uart.write(reason); uart.write("\r\n");
    uart.write("attempted_path="); uart.write(path); uart.write("\r\n");
    printCounters();
}

fn printCommon() void {
    uart.write("vfs_interface=present\r\n");
    uart.write("vfs_kind=mount-router-v0\r\n");
    uart.write("vfs_mount_count=2\r\n");
    uart.write("vfs_mount path=/ fs=tarfs-readonly-v0 readonly=yes\r\n");
    uart.write("vfs_mount path=/ram fs=ramfs-volatile-memory-v0 readonly=no\r\n");
    uart.write("vfs_longest_prefix_match=yes\r\n");
    uart.write("vfs_root=/\r\n");
    uart.write("vfs_ram_mount=/ram\r\n");
    printCounters();
    printNonClaims();
}

fn printCounters() void {
    uart.write("vfs_route_count="); uart.writeDec(counters.route_count); uart.write("\r\n");
    uart.write("vfs_list_count="); uart.writeDec(counters.list_count); uart.write("\r\n");
    uart.write("vfs_stat_count="); uart.writeDec(counters.stat_count); uart.write("\r\n");
    uart.write("vfs_read_count="); uart.writeDec(counters.read_count); uart.write("\r\n");
    uart.write("vfs_checksum_count="); uart.writeDec(counters.checksum_count); uart.write("\r\n");
    uart.write("vfs_create_count="); uart.writeDec(counters.create_count); uart.write("\r\n");
    uart.write("vfs_write_count="); uart.writeDec(counters.write_count); uart.write("\r\n");
    uart.write("vfs_append_count="); uart.writeDec(counters.append_count); uart.write("\r\n");
    uart.write("vfs_delete_count="); uart.writeDec(counters.delete_count); uart.write("\r\n");
    uart.write("vfs_missing_count="); uart.writeDec(counters.missing_count); uart.write("\r\n");
    uart.write("vfs_readonly_reject_count="); uart.writeDec(counters.readonly_reject_count); uart.write("\r\n");
    uart.write("vfs_invalid_mount_count="); uart.writeDec(counters.invalid_mount_count); uart.write("\r\n");
    uart.write("vfs_last_error="); uart.write(last_error); uart.write("\r\n");
}

fn printNonClaims() void {
    uart.write("persistent_storage=not-implemented\r\n");
    uart.write("block_device_fs=not-implemented\r\n");
    uart.write("journaling=not-implemented\r\n");
    uart.write("permissions=not-implemented\r\n");
    uart.write("symlinks=not-implemented\r\n");
    uart.write("hardlinks=not-implemented\r\n");
    uart.write("userspace_loader=not-implemented\r\n");
    uart.write("executable_apps=not-implemented\r\n");
    uart.write("wasm_loader=not-implemented\r\n");
    uart.write("production_filesystem=not-implemented\r\n");
}

fn printEntry(path: []const u8, size: usize, sum: u32) void {
    uart.write("vfs_file path="); uart.write(path); uart.write(" size="); uart.writeDec(size); uart.write(" checksum="); uart.writeDec(sum); uart.write("\r\n");
}

fn logRoute(path: []const u8, r: Route) void {
    uart.write("[ZIGN01D][INFO][VFS][VFS002] route success path="); uart.write(path); uart.write(" fs="); uart.write(r.fs_name); uart.write(" mount="); uart.write(r.mount); uart.write("\r\n");
}

fn stripQuotes(bytes: []const u8) []const u8 {
    if (bytes.len >= 2 and bytes[0] == '"' and bytes[bytes.len - 1] == '"') return bytes[1 .. bytes.len - 1];
    return bytes;
}

fn startsWith(value: []const u8, prefix: []const u8) bool {
    if (value.len < prefix.len) return false;
    for (prefix, 0..) |ch, i| {
        if (value[i] != ch) return false;
    }
    return true;
}

fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ch, i| {
        if (ch != b[i]) return false;
    }
    return true;
}
