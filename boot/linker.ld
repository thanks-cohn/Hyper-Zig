/* V0 RISC-V kernel linker skeleton. */
OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    . = 0x80200000;

    .text : ALIGN(4K) {
        *(.text.entry)
        *(.text*)
    }

    .rodata : ALIGN(4K) { *(.rodata*) }
    .data : ALIGN(4K) { *(.data*) }
    .bss : ALIGN(4K) {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    }
}
