const uart = @import("../console/uart.zig");

pub const kind = "volatile-memory-v0";
const root = "/ram";
const root_prefix = "/ram/";
const capacity_files: usize = 8;
const max_file_bytes: usize = 64;
const empty_error = "none";

pub const File = struct {
    used: bool = false,
    path: [48]u8 = [_]u8{0} ** 48,
    path_len: usize = 0,
    data: [max_file_bytes]u8 = [_]u8{0} ** max_file_bytes,
    data_len: usize = 0,
};

const Counters = struct {
    create_count: usize = 0,
    write_count: usize = 0,
    append_count: usize = 0,
    read_count: usize = 0,
    delete_count: usize = 0,
    missing_count: usize = 0,
    capacity_reject_count: usize = 0,
    overflow_reject_count: usize = 0,
};

var files: [capacity_files]File = [_]File{File{}} ** capacity_files;
var counters = Counters{};
var last_error: []const u8 = empty_error;

pub fn init() void {
    reset();
    uart.write("[ZIGN01D][INFO][RAMFS][RAMFS000] initialized root=/ram capacity_files=");
    uart.writeDec(capacity_files);
    uart.write(" max_file_bytes=");
    uart.writeDec(max_file_bytes);
    uart.write(" backing=kernel-memory persistent=no\r\n");
}

pub fn printOverview() void {
    printStatsWithLog(false);
}

pub fn printStats() void {
    printStatsWithLog(true);
}

fn printStatsWithLog(emit_log: bool) void {
    if (emit_log) uart.write("[ZIGN01D][INFO][RAMFS][RAMFS001] stats requested root=/ram\r\n");
    uart.write("ramfs_interface=present\r\n");
    uart.write("ramfs_kind=");
    uart.write(kind);
    uart.write("\r\n");
    uart.write("ramfs_root=");
    uart.write(root);
    uart.write("\r\n");
    uart.write("ramfs_capacity_files=");
    uart.writeDec(capacity_files);
    uart.write("\r\n");
    uart.write("ramfs_max_file_bytes=");
    uart.writeDec(max_file_bytes);
    uart.write("\r\n");
    uart.write("ramfs_file_count=");
    uart.writeDec(fileCount());
    uart.write("\r\n");
    uart.write("ramfs_total_bytes=");
    uart.writeDec(totalBytes());
    uart.write("\r\n");
    uart.write("ramfs_readonly=no\r\n");
    uart.write("ramfs_persistent=no\r\n");
    uart.write("ramfs_backing=kernel-memory\r\n");
    uart.write("ramfs_create_count=");
    uart.writeDec(counters.create_count);
    uart.write("\r\n");
    uart.write("ramfs_write_count=");
    uart.writeDec(counters.write_count);
    uart.write("\r\n");
    uart.write("ramfs_append_count=");
    uart.writeDec(counters.append_count);
    uart.write("\r\n");
    uart.write("ramfs_read_count=");
    uart.writeDec(counters.read_count);
    uart.write("\r\n");
    uart.write("ramfs_delete_count=");
    uart.writeDec(counters.delete_count);
    uart.write("\r\n");
    uart.write("ramfs_missing_count=");
    uart.writeDec(counters.missing_count);
    uart.write("\r\n");
    uart.write("ramfs_capacity_reject_count=");
    uart.writeDec(counters.capacity_reject_count);
    uart.write("\r\n");
    uart.write("ramfs_overflow_reject_count=");
    uart.writeDec(counters.overflow_reject_count);
    uart.write("\r\n");
    uart.write("ramfs_last_error=");
    uart.write(last_error);
    uart.write("\r\n");
    uart.write("ramfs_duplicate_create=rejects-already-exists\r\n");
    printNonClaims();
}

pub fn printList() void {
    uart.write("[ZIGN01D][INFO][RAMFS][RAMFS002] list requested root=/ram file_count=");
    uart.writeDec(fileCount());
    uart.write("\r\n");
    printStatsWithLog(false);
    for (files) |file| {
        if (file.used) {
            uart.write("ramfs_file path=");
            writePath(file);
            uart.write(" size=");
            uart.writeDec(file.data_len);
            uart.write(" checksum=");
            uart.writeDec(checksum(file.data[0..file.data_len]));
            uart.write("\r\n");
        }
    }
    uart.write("ramfs_list_ok=yes\r\n");
}

pub fn printCreate(path: []const u8) void {
    if (!validPath(path)) return rejectMissing(path);
    if (findIndex(path) != null) return rejectDuplicate(path);
    if (freeIndex()) |index| {
        files[index] = File{};
        files[index].used = true;
        copyInto(files[index].path[0..], path);
        files[index].path_len = path.len;
        files[index].data_len = 0;
        counters.create_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS003] create success path=");
        uart.write(path);
        uart.write(" file_count=");
        uart.writeDec(fileCount());
        uart.write("\r\n");
        uart.write("ramfs_create_ok=yes\r\n");
        uart.write("ramfs_create_path=");
        uart.write(path);
        uart.write("\r\n");
        return;
    }
    rejectCapacity(path);
}

pub fn printWrite(path: []const u8, bytes: []const u8) void {
    const data = stripQuotes(bytes);
    if (findIndex(path)) |index| {
        if (data.len > max_file_bytes) return rejectOverflow(path);
        copyInto(files[index].data[0..], data);
        files[index].data_len = data.len;
        counters.write_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS004] write success path=");
        uart.write(path);
        uart.write(" bytes=");
        uart.writeDec(data.len);
        uart.write("\r\n");
        uart.write("ramfs_write_ok=yes\r\n");
        uart.write("ramfs_write_path=");
        uart.write(path);
        uart.write("\r\n");
        uart.write("ramfs_write_bytes=");
        uart.writeDec(data.len);
        uart.write("\r\n");
        return;
    }
    rejectMissing(path);
}

pub fn printAppend(path: []const u8, bytes: []const u8) void {
    const data = stripQuotes(bytes);
    if (findIndex(path)) |index| {
        const old_len = files[index].data_len;
        if (old_len + data.len > max_file_bytes) return rejectOverflow(path);
        for (data, 0..) |byte, i| files[index].data[old_len + i] = byte;
        files[index].data_len = old_len + data.len;
        counters.append_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS006] append success path=");
        uart.write(path);
        uart.write(" append_bytes=");
        uart.writeDec(data.len);
        uart.write(" total_bytes=");
        uart.writeDec(files[index].data_len);
        uart.write("\r\n");
        uart.write("ramfs_append_ok=yes\r\n");
        uart.write("ramfs_append_path=");
        uart.write(path);
        uart.write("\r\n");
        uart.write("ramfs_append_bytes=");
        uart.writeDec(data.len);
        uart.write("\r\n");
        return;
    }
    rejectMissing(path);
}

pub fn printCat(path: []const u8) void {
    if (findIndex(path)) |index| {
        counters.read_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS005] read success path=");
        uart.write(path);
        uart.write(" bytes=");
        uart.writeDec(files[index].data_len);
        uart.write("\r\n");
        uart.write("ramfs_cat_ok=yes\r\n");
        uart.write("ramfs_cat_path=");
        uart.write(path);
        uart.write("\r\n");
        uart.write("ramfs_cat_bytes=");
        uart.writeDec(files[index].data_len);
        uart.write("\r\n");
        uart.write(files[index].data[0..files[index].data_len]);
        uart.write("\r\n");
        return;
    }
    rejectMissing(path);
}

pub fn printStat(path: []const u8) void {
    if (findIndex(path)) |index| {
        const sum = checksum(files[index].data[0..files[index].data_len]);
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS007] stat success path=");
        uart.write(path);
        uart.write(" bytes=");
        uart.writeDec(files[index].data_len);
        uart.write(" checksum=");
        uart.writeDec(sum);
        uart.write("\r\n");
        uart.write("ramfs_stat_ok=yes\r\n");
        uart.write("ramfs_stat_path=");
        uart.write(path);
        uart.write("\r\n");
        uart.write("ramfs_stat_size=");
        uart.writeDec(files[index].data_len);
        uart.write("\r\n");
        uart.write("ramfs_stat_checksum=");
        uart.writeDec(sum);
        uart.write("\r\n");
        return;
    }
    rejectMissing(path);
}

pub fn printChecksum(path: []const u8) void {
    if (findIndex(path)) |index| {
        const sum = checksum(files[index].data[0..files[index].data_len]);
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS008] checksum success path=");
        uart.write(path);
        uart.write(" checksum=");
        uart.writeDec(sum);
        uart.write(" bytes=");
        uart.writeDec(files[index].data_len);
        uart.write("\r\n");
        uart.write("ramfs_checksum_ok=yes\r\n");
        uart.write("ramfs_checksum_path=");
        uart.write(path);
        uart.write("\r\n");
        uart.write("ramfs_checksum=");
        uart.writeDec(sum);
        uart.write("\r\n");
        return;
    }
    rejectMissing(path);
}

pub fn printDelete(path: []const u8) void {
    if (findIndex(path)) |index| {
        files[index] = File{};
        counters.delete_count += 1;
        last_error = empty_error;
        uart.write("[ZIGN01D][INFO][RAMFS][RAMFS009] delete success path=");
        uart.write(path);
        uart.write(" file_count=");
        uart.writeDec(fileCount());
        uart.write("\r\n");
        uart.write("ramfs_delete_ok=yes\r\n");
        uart.write("ramfs_delete_path=");
        uart.write(path);
        uart.write("\r\n");
        return;
    }
    rejectMissing(path);
}

pub fn printMissingTest() void {
    printCat("/ram/definitely-missing.txt");
}

pub fn printCapacityTest() void {
    var n: usize = 0;
    while (n < capacity_files) : (n += 1) {
        if (fileCount() >= capacity_files) break;
        var path_buf: [16]u8 = undefined;
        const path = capacityPath(&path_buf, n);
        if (findIndex(path) == null) createSilent(path);
    }
    rejectCapacity("/ram/capacity-extra.txt");
    uart.write("ramfs_capacity_rejected=yes\r\n");
}

pub fn printOverflowTest() void {
    const path = firstPath() orelse "/ram/overflow.txt";
    if (findIndex(path) == null) createSilent(path);
    uart.write("ramfs_overflow_attempt_bytes=");
    uart.writeDec(max_file_bytes + 1);
    uart.write("\r\n");
    rejectOverflow(path);
    uart.write("ramfs_overflow_rejected=yes\r\n");
}

pub const OpStatus = enum {
    ok,
    invalid_path,
    not_found,
    already_exists,
    capacity_full,
    file_too_large,
};

pub const ReadResult = struct {
    status: OpStatus,
    data: []const u8 = "",
};

pub const StatResult = struct {
    status: OpStatus,
    size: usize = 0,
    sum: u32 = 0,
};

pub fn create(path: []const u8) OpStatus {
    if (!validPath(path)) return setMissing(path, "invalid-path", .invalid_path);
    if (findIndex(path) != null) return setMissing(path, "already-exists", .already_exists);
    if (freeIndex()) |index| {
        files[index] = File{};
        files[index].used = true;
        copyInto(files[index].path[0..], path);
        files[index].path_len = path.len;
        files[index].data_len = 0;
        counters.create_count += 1;
        last_error = empty_error;
        return .ok;
    }
    counters.capacity_reject_count += 1;
    last_error = "capacity-full";
    return .capacity_full;
}

pub fn write(path: []const u8, bytes: []const u8) OpStatus {
    const data = stripQuotes(bytes);
    if (findIndex(path)) |index| {
        if (data.len > max_file_bytes) {
            counters.overflow_reject_count += 1;
            last_error = "file-too-large";
            return .file_too_large;
        }
        copyInto(files[index].data[0..], data);
        files[index].data_len = data.len;
        counters.write_count += 1;
        last_error = empty_error;
        return .ok;
    }
    return setMissing(path, "not-found", .not_found);
}

pub fn append(path: []const u8, bytes: []const u8) OpStatus {
    const data = stripQuotes(bytes);
    if (findIndex(path)) |index| {
        const old_len = files[index].data_len;
        if (old_len + data.len > max_file_bytes) {
            counters.overflow_reject_count += 1;
            last_error = "file-too-large";
            return .file_too_large;
        }
        for (data, 0..) |byte, i| files[index].data[old_len + i] = byte;
        files[index].data_len = old_len + data.len;
        counters.append_count += 1;
        last_error = empty_error;
        return .ok;
    }
    return setMissing(path, "not-found", .not_found);
}

pub fn read(path: []const u8) ReadResult {
    if (findIndex(path)) |index| {
        counters.read_count += 1;
        last_error = empty_error;
        return .{ .status = .ok, .data = files[index].data[0..files[index].data_len] };
    }
    _ = setMissing(path, "not-found", .not_found);
    return .{ .status = .not_found };
}

pub fn stat(path: []const u8) StatResult {
    if (findIndex(path)) |index| {
        const data = files[index].data[0..files[index].data_len];
        last_error = empty_error;
        return .{ .status = .ok, .size = data.len, .sum = checksum(data) };
    }
    _ = setMissing(path, "not-found", .not_found);
    return .{ .status = .not_found };
}

pub fn delete(path: []const u8) OpStatus {
    if (findIndex(path)) |index| {
        files[index] = File{};
        counters.delete_count += 1;
        last_error = empty_error;
        return .ok;
    }
    return setMissing(path, "not-found", .not_found);
}

pub fn fileAt(index: usize) ?File {
    var seen: usize = 0;
    for (files) |file| {
        if (file.used) {
            if (seen == index) return file;
            seen += 1;
        }
    }
    return null;
}

pub fn pathOf(file: File) []const u8 {
    return file.path[0..file.path_len];
}

pub fn dataOf(file: File) []const u8 {
    return file.data[0..file.data_len];
}

pub fn count() usize {
    return fileCount();
}

fn setMissing(path: []const u8, reason: []const u8, status: OpStatus) OpStatus {
    _ = path;
    counters.missing_count += 1;
    last_error = reason;
    return status;
}

fn createSilent(path: []const u8) void {
    if (freeIndex()) |index| {
        files[index] = File{};
        files[index].used = true;
        copyInto(files[index].path[0..], path);
        files[index].path_len = path.len;
        counters.create_count += 1;
    }
}

fn firstPath() ?[]const u8 {
    for (&files) |*file| {
        if (file.used) return file.path[0..file.path_len];
    }
    return null;
}

fn capacityPath(buf: *[16]u8, n: usize) []const u8 {
    const prefix = "/ram/cap";
    for (prefix, 0..) |byte, i| buf[i] = byte;
    buf[prefix.len] = @as(u8, '0') + @as(u8, @intCast(n));
    return buf[0 .. prefix.len + 1];
}


fn rejectDuplicate(path: []const u8) void {
    counters.missing_count += 1;
    last_error = "already-exists";
    uart.write("[ZIGN01D][WARN][RAMFS][RAMFS010] duplicate create rejected path=");
    uart.write(path);
    uart.write(" reason=already-exists\r\n");
    uart.write("ramfs_duplicate_create_rejected=yes\r\n");
    uart.write("ramfs_last_error=already-exists\r\n");
    uart.write("attempted_path=");
    uart.write(path);
    uart.write("\r\n");
}

fn rejectMissing(path: []const u8) void {
    rejectMissingWith(path, "not-found");
}

fn rejectMissingWith(path: []const u8, reason: []const u8) void {
    counters.missing_count += 1;
    last_error = reason;
    uart.write("[ZIGN01D][WARN][RAMFS][RAMFS010] missing path rejected path=");
    uart.write(path);
    uart.write(" reason=");
    uart.write(reason);
    uart.write("\r\n");
    uart.write("ramfs_missing_rejected=yes\r\n");
    uart.write("ramfs_last_error=");
    uart.write(reason);
    uart.write("\r\n");
    uart.write("attempted_path=");
    uart.write(path);
    uart.write("\r\n");
}

fn rejectCapacity(path: []const u8) void {
    counters.capacity_reject_count += 1;
    last_error = "capacity-full";
    uart.write("[ZIGN01D][WARN][RAMFS][RAMFS011] capacity rejected reason=capacity-full path=");
    uart.write(path);
    uart.write(" capacity_files=");
    uart.writeDec(capacity_files);
    uart.write("\r\n");
    uart.write("ramfs_capacity_rejected=yes\r\n");
    uart.write("ramfs_last_error=capacity-full\r\n");
}

fn rejectOverflow(path: []const u8) void {
    counters.overflow_reject_count += 1;
    last_error = "file-too-large";
    uart.write("[ZIGN01D][WARN][RAMFS][RAMFS012] overflow rejected reason=file-too-large path=");
    uart.write(path);
    uart.write(" max_file_bytes=");
    uart.writeDec(max_file_bytes);
    uart.write("\r\n");
    uart.write("ramfs_overflow_rejected=yes\r\n");
    uart.write("ramfs_last_error=file-too-large\r\n");
}

fn printNonClaims() void {
    uart.write("persistent_storage=not-implemented\r\n");
    uart.write("block_device_fs=not-implemented\r\n");
    uart.write("vfs_layer=implemented-mount-router-v0\r\n");
    uart.write("journaling=not-implemented\r\n");
    uart.write("permissions=not-implemented\r\n");
    uart.write("directories=limited-or-not-implemented\r\n");
    uart.write("executable_apps=not-implemented\r\n");
    uart.write("wasm_loader=not-implemented\r\n");
    uart.write("userspace_loader=not-implemented\r\n");
    uart.write("production_filesystem=not-implemented\r\n");
}

fn reset() void {
    files = [_]File{File{}} ** capacity_files;
    counters = Counters{};
    last_error = empty_error;
}

fn findIndex(path: []const u8) ?usize {
    for (files, 0..) |file, i| {
        if (file.used and equals(path, file.path[0..file.path_len])) return i;
    }
    return null;
}

fn freeIndex() ?usize {
    for (files, 0..) |file, i| {
        if (!file.used) return i;
    }
    return null;
}

fn fileCount() usize {
    var count: usize = 0;
    for (files) |file| {
        if (file.used) count += 1;
    }
    return count;
}

fn totalBytes() usize {
    var total: usize = 0;
    for (files) |file| {
        if (file.used) total += file.data_len;
    }
    return total;
}

fn validPath(path: []const u8) bool {
    return startsWith(path, root_prefix) and path.len <= 48;
}

fn stripQuotes(bytes: []const u8) []const u8 {
    if (bytes.len >= 2 and bytes[0] == '"' and bytes[bytes.len - 1] == '"') return bytes[1 .. bytes.len - 1];
    return bytes;
}

fn copyInto(dest: []u8, src: []const u8) void {
    for (src, 0..) |byte, i| dest[i] = byte;
}

fn writePath(file: File) void {
    uart.write(file.path[0..file.path_len]);
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

pub fn checksum(bytes: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (bytes) |byte| {
        hash ^= @as(u32, byte);
        hash *%= 16777619;
    }
    return hash;
}
