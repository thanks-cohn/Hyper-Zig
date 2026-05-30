    .section .text.entry
    .globl _start
_start:
    /* TODO: set up an initial stack, clear BSS, and call kmain. */
1:
    wfi
    j 1b
