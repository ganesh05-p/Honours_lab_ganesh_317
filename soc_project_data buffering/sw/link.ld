/* =============================================================================
 * Linker Script: link.ld
 * Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
 * Architecture: RV32IMC
 *
 * Memory Map Resolution:
 *   - Executable ROM / ICCM: 0xEE00_0000 - 0xEE00_FFFF (64 KiB)
 *     Boot address: rst_vec = 0xEE00_0000 (VeeR EL2 core reset vector).
 *     VeeR EL2 fetches instructions strictly from ICCM (IFU AXI port is tied off).
 *   - Data RAM / DCCM      : 0xF004_0000 - 0xF004_FFFF (64 KiB)
 *     Tightly coupled data memory for stack, BSS, and local C variables.
 *   - System Shared DMEM   : 0x1000_0000 - 0x10FF_FFFF (AXI Slave Port M01)
 *     External AXI RAM accessible by both CPU LSU and DMA engine (DMA buffer).
 *   - System Shared IMEM   : 0x0000_0000 - 0x00FF_FFFF (AXI Slave Port M00)
 *     External AXI RAM aperture (unconnected to core IFU in this SoC configuration).
 * ============================================================================= */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* Instruction Closely Coupled Memory (ICCM: 64 KiB) */
    ROM (rx)  : ORIGIN = 0xEE000000, LENGTH = 64K
    /* Data Closely Coupled Memory (DCCM: 64 KiB) */
    RAM (rwx) : ORIGIN = 0xF0040000, LENGTH = 64K
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        *(.text.init)
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        . = ALIGN(4);
        _etext = .;
    } > ROM

    _sidata = LOADADDR(.data);

    .data : AT(_etext)
    {
        . = ALIGN(4);
        _sdata = .;
        __global_pointer$ = . + 0x800;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    .stack (NOLOAD) :
    {
        . = ALIGN(16);
        . += 0x1000; /* 4 KiB stack */
        _stack_top = .;
    } > RAM

    _end = .;
}

