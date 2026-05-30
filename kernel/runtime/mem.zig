pub export fn memset(dest: [*]u8, c: c_int, n: usize) callconv(.C) [*]u8 {
    var i: usize = 0;
    const byte: u8 = @intCast(c & 0xff);
    while (i < n) : (i += 1) {
        dest[i] = byte;
    }
    return dest;
}

pub export fn memcpy(dest: [*]u8, src: [*]const u8, n: usize) callconv(.C) [*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        dest[i] = src[i];
    }
    return dest;
}

pub export fn memmove(dest: [*]u8, src: [*]const u8, n: usize) callconv(.C) [*]u8 {
    if (@intFromPtr(dest) < @intFromPtr(src)) {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            dest[i] = src[i];
        }
    } else {
        var i: usize = n;
        while (i > 0) {
            i -= 1;
            dest[i] = src[i];
        }
    }
    return dest;
}

pub fn force_link() void {
    _ = memset;
    _ = memcpy;
    _ = memmove;
}
