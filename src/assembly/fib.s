.text
.align 2
.globl _start

_start:
    li      sp, 0x1f0       # at top of 256-byte RAM
    li      a0, 5
    call    fib
    ebreak

fib:
    li      a5, 1
    ble     a0, a5, Exit

    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)

    mv      s0, a0
    addi    a0, a0, -1
    call    fib
    mv      s1, a0
    addi    a0, s0, -2
    call    fib
    add     a0, s1, a0

    lw      ra, 12(sp)
    lw      s0, 8(sp)
    lw      s1, 4(sp)
    addi    sp, sp, 16
    ret

Exit:
    li      a0, 1
    ret

