# =============================================================================
# Startup: startup.s
# Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
# Description: CRT0 assembly startup and exception handler for VeeR EL2 (RV32IMC)
# =============================================================================

    .section .text.init
    .globl _start
    .type _start, @function

_start:
    # Disable interrupts initially
    csrw mstatus, zero
    csrw mie, zero

    # Set trap vector to default handler
    la t0, _trap_handler
    csrw mtvec, t0

    # Configure VeeR EL2 Memory Region Attributes Control register (MRAC, CSR 0x7c0)
    # 0x55555555 configures non-side-effect, standard memory access across regions
    li t0, 0x55555555
    csrw 0x7c0, t0

    # Initialize global pointer
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # Initialize stack pointer to top of DCCM stack region (0xF004_0000)
    la sp, _stack_top

    # Copy initialized data from ROM (LMA _sidata in ICCM) to RAM (VMA _sdata in DCCM)
    la a0, _sidata
    la a1, _sdata
    la a2, _edata
    bge a1, a2, 2f
1:
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    blt a1, a2, 1b
2:

    # Clear BSS section in DCCM
    la a0, _bss_start
    la a1, _bss_end
    bge a0, a1, 4f
3:
    sw zero, 0(a0)
    addi a0, a0, 4
    blt a0, a1, 3b
4:

    # Call main application
    call main

    # Halt loop after completion
_exit:
    wfi
    j _exit

    .align 4
_trap_handler:
    mret

    .size _start, . - _start
