.section .text
.globl _start

_start:
    lui     t0, 0x80000
    addi    t0, t0, 0x100

    lh      t1, 0(t0)
    sh      t1, 0(t0)
