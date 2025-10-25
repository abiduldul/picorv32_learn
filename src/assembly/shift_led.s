.section .text
.globl _start

_start:
    lui     t0, 0x80000
    addi    t0, t0, 0x100

loop:
    li t1, 0x0001
    sh t1, 0(t0)

    li t1, 0x0002
    sh t1, 0(t0)

    li t1, 0x0004
    sh t1, 0(t0)

    li t1, 0x0008
    sh t1, 0(t0)

    li t1, 0x0010
    sh t1, 0(t0)

    li t1, 0x0020
    sh t1, 0(t0)

    li t1, 0x0040
    sh t1, 0(t0)

    li t1, 0x0080
    sh t1, 0(t0)

    li t1, 0x0100
    sh t1, 0(t0)

    li t1, 0x0200
    sh t1, 0(t0)

    li t1, 0x0400
    sh t1, 0(t0)

    li t1, 0x0800
    sh t1, 0(t0)

    li t1, 0x1000
    sh t1, 0(t0)

    li t1, 0x2000
    sh t1, 0(t0)

    li t1, 0x4000
    sh t1, 0(t0)

    li t1, 0x8000
    sh t1, 0(t0)

    j loop
