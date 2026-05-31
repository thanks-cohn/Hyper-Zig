const uart = @import("../console/uart.zig");

pub const kind = "tarfs-readonly-v0";
const root = "/";
const mount_count: usize = 1;

pub const File = struct {
    path: []const u8,
    data: []const u8,
    checksum: u32,
};

const hello_txt = "hello from zign01d tarfs";
const readme_txt = "ZIGN01D TARFS V0\nread-only embedded archive for early kernel file inspection\n";
const hello_app =
    \\name=hello
    \\kind=app-manifest-data-only
    \\executable=no
    \\note=this TARFS V0 record is data only, not executable code
;
const release_txt =
    \\name=ZIGN01D
    \\version=0
    \\milestone=TARFS_V0_INITRD_V0
    \\filesystem=tarfs-readonly-v0
;

pub const files = [_]File{
    .{ .path = "/hello.txt", .data = hello_txt, .checksum = checksum(hello_txt) },
    .{ .path = "/readme.txt", .data = readme_txt, .checksum = checksum(readme_txt) },
    .{ .path = "/apps/hello.app", .data = hello_app, .checksum = checksum(hello_app) },
    .{ .path = "/etc/zign01d-release", .data = release_txt, .checksum = checksum(release_txt) },
};

pub fn init() void {
    uart.write("[ZIGN01D][INFO][FS][FS000] tarfs initialized file_count=");
    uart.writeDec(fileCount());
    uart.write(" total_bytes=");
    uart.writeDec(totalBytes());
    uart.write(" readonly=yes root=/\r\n");
}

pub fn printOverview() void {
    uart.write("fs_interface=present\r\n");
    uart.write("fs_kind=");
    uart.write(kind);
    uart.write("\r\n");
    uart.write("fs_file_count=");
    uart.writeDec(fileCount());
    uart.write("\r\n");
    uart.write("fs_total_bytes=");
    uart.writeDec(totalBytes());
    uart.write("\r\n");
    uart.write("fs_readonly=yes\r\n");
    uart.write("fs_write=not-implemented\r\n");
    uart.write("fs_mount_count=");
    uart.writeDec(mount_count);
    uart.write("\r\n");
    uart.write("fs_root=");
    uart.write(root);
    uart.write("\r\n");
    uart.write("vfs_layer=implemented-mount-router-v0\r\n");
    uart.write("block_device_fs=not-implemented\r\n");
    uart.write("persistent_storage=not-implemented\r\n");
    uart.write("executable_apps=not-implemented\r\n");
    uart.write("wasm_loader=not-implemented\r\n");
    uart.write("userspace_loader=not-implemented\r\n");
    uart.write("permissions=not-implemented\r\n");
    uart.write("production_filesystem=not-implemented\r\n");
}

pub fn printList() void {
    uart.write("[ZIGN01D][INFO][FS][FS001] file list requested root=/ file_count=");
    uart.writeDec(fileCount());
    uart.write("\r\n");
    printOverview();
    for (files) |file| {
        uart.write("fs_file path=");
        uart.write(file.path);
        uart.write(" size=");
        uart.writeDec(file.data.len);
        uart.write(" checksum=");
        uart.writeDec(file.checksum);
        uart.write("\r\n");
    }
    uart.write("fs_list_ok=yes\r\n");
}

pub fn printStat(path: []const u8) void {
    if (find(path)) |file| {
        uart.write("[ZIGN01D][INFO][FS][FS002] stat success path=");
        uart.write(file.path);
        uart.write(" bytes=");
        uart.writeDec(file.data.len);
        uart.write(" checksum=");
        uart.writeDec(file.checksum);
        uart.write("\r\n");
        uart.write("fs_stat_ok=yes\r\n");
        uart.write("fs_stat_path=");
        uart.write(file.path);
        uart.write("\r\n");
        uart.write("fs_stat_size=");
        uart.writeDec(file.data.len);
        uart.write("\r\n");
        uart.write("fs_stat_checksum=");
        uart.writeDec(file.checksum);
        uart.write("\r\n");
        return;
    }
    missing(path);
}

pub fn printCat(path: []const u8) void {
    if (find(path)) |file| {
        uart.write("[ZIGN01D][INFO][FS][FS003] read success path=");
        uart.write(file.path);
        uart.write(" bytes=");
        uart.writeDec(file.data.len);
        uart.write("\r\n");
        uart.write("fs_cat_ok=yes\r\n");
        uart.write("fs_cat_path=");
        uart.write(file.path);
        uart.write("\r\n");
        uart.write("fs_cat_bytes=");
        uart.writeDec(file.data.len);
        uart.write("\r\n");
        uart.write(file.data);
        uart.write("\r\n");
        return;
    }
    missing(path);
}

pub fn printChecksum(path: []const u8) void {
    if (find(path)) |file| {
        uart.write("[ZIGN01D][INFO][FS][FS004] checksum success path=");
        uart.write(file.path);
        uart.write(" checksum=");
        uart.writeDec(file.checksum);
        uart.write(" bytes=");
        uart.writeDec(file.data.len);
        uart.write("\r\n");
        uart.write("fs_checksum_ok=yes\r\n");
        uart.write("fs_checksum_path=");
        uart.write(file.path);
        uart.write("\r\n");
        uart.write("fs_checksum=");
        uart.writeDec(file.checksum);
        uart.write("\r\n");
        return;
    }
    missing(path);
}

pub fn printWriteTest() void {
    uart.write("[ZIGN01D][WARN][FS][FS006] write rejected path=/hello.txt reason=read-only\r\n");
    uart.write("fs_write_rejected=yes\r\n");
    uart.write("fs_last_error=read-only\r\n");
    uart.write("fs_write=not-implemented\r\n");
}

fn missing(path: []const u8) void {
    uart.write("[ZIGN01D][WARN][FS][FS005] missing file rejected path=");
    uart.write(path);
    uart.write(" reason=not-found\r\n");
    uart.write("fs_missing_rejected=yes\r\n");
    uart.write("fs_last_error=not-found\r\n");
    uart.write("attempted_path=");
    uart.write(path);
    uart.write("\r\n");
}

pub fn find(path: []const u8) ?File {
    for (files) |file| {
        if (equals(path, file.path)) return file;
    }
    return null;
}

pub fn fileCount() usize {
    return files.len;
}

pub fn totalBytes() usize {
    var total: usize = 0;
    for (files) |file| total += file.data.len;
    return total;
}

fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ch, i| {
        if (ch != b[i]) return false;
    }
    return true;
}

pub fn checksum(bytes: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (bytes) |byte| {
        hash ^= @as(u32, byte);
        hash *%= 16777619;
    }
    return hash;
}
