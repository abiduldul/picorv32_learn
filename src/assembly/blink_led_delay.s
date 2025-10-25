.section .text
.globl _start

_start:
    lui     t0, 0x40000
    addi    t0, t0, 0x000

loop:
    li      t1, 0xFFFFFFFF          # led on
    sh      t1, 0(t0)
    li      t2, 5000000             # delay

delay_on:
    addi    t2, t2, -1
    bne     t2, x0, delay_on
    li      t1, 0x00000000          # led off
    sh      t1, 0(t0)
    li      t2, 5000000             # delay
    
delay_off:
    addi    t2, t2, -1
    bne     t2, x0, delay_off
    j       loop
