    .section .text.entry, "ax", @progbits
    .option norvc
    .globl _start
_start:
    la sp, __stack_top

    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sd zero, 0(t0)
    addi t0, t0, 8
    j 1b
2:
    la t0, zign01d_boot_hart_id
    sd a0, 0(t0)

    call kmain
3:
    wfi
    j 3b

    .section .text.trap, "ax", @progbits
    .globl zign01d_trap_vector
zign01d_trap_vector:
    csrr a0, scause
    csrr a1, sepc
    csrr a2, stval
    tail zign01d_handle_trap

    .section .bss.boot, "aw", @nobits
    .globl zign01d_boot_hart_id
    .align 3
zign01d_boot_hart_id:
    .dword 0
