.section .text
.globl _start

_start:
    lui     t0, 0x80000
    addi    t0, t0, 0x100

loop:
    li      t1, 0xFFFF
    sh      t1, 0(t0)

    li      t1, 0x0000
    sh      t1, 0(t0)

    j       loop
