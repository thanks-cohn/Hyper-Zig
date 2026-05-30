const UART0_BASE: usize = 0x1000_0000;
const UART_RHR: usize = 0;
const UART_THR: usize = 0;
const UART_LSR: usize = 5;
const LSR_RX_READY: u8 = 1 << 0;
const LSR_TX_IDLE: u8 = 1 << 5;

fn reg(offset: usize) *volatile u8 {
    return @ptrFromInt(UART0_BASE + offset);
}

pub fn init() void {
    // QEMU virt exposes a 16550-compatible UART that is ready for polling IO.
    write("[ZIGN01D][INFO][UART][UART001] uart initialized at qemu virt mmio 0x10000000\r\n");
}

pub fn putByte(byte: u8) void {
    while ((reg(UART_LSR).* & LSR_TX_IDLE) == 0) {}
    reg(UART_THR).* = byte;
}

pub fn write(bytes: []const u8) void {
    for (bytes) |byte| {
        if (byte == '\n') putByte('\r');
        putByte(byte);
    }
}

pub fn readByteBlocking() u8 {
    while ((reg(UART_LSR).* & LSR_RX_READY) == 0) {
        asm volatile ("nop");
    }
    return reg(UART_RHR).*;
}

pub fn writeDec(value: u64) void {
    var buf: [20]u8 = undefined;
    var i: usize = buf.len;
    var n = value;
    if (n == 0) {
        putByte('0');
        return;
    }
    while (n > 0) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(n % 10));
        n /= 10;
    }
    write(buf[i..]);
}

pub fn writeHex(value: usize) void {
    write("0x");
    var shift: usize = (@sizeOf(usize) * 8) - 4;
    var started = false;
    while (true) {
        const nibble: u8 = @intCast((value >> @intCast(shift)) & 0xf);
        if (nibble != 0 or started or shift == 0) {
            started = true;
            putByte(if (nibble < 10) '0' + nibble else 'a' + (nibble - 10));
        }
        if (shift == 0) break;
        shift -= 4;
    }
}
