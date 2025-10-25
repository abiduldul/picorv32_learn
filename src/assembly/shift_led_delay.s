.section .text
.globl _start

_start:
    lui     t0, 0x80000
    addi    t0, t0, 0x100
    li      t3, 0x0001

loop:
    sh      t3, 0(t0)
    li      t2, 5000000

delay_on:
    addi    t2, t2, -1
    bne     t2, x0, delay_on
    li      t1, 0x0000
    sh      t1, 0(t0)
    li      t2, 5000000

delay_off:
    addi    t2, t2, -1
    bne     t2, x0, delay_off
    slli    t3, t3, 1
    beq     t3, x0, reset
    j       loop
    
reset:
    li      t3, 0x0001
    j       loop