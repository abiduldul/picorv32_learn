.text
.align  2
.globl  _start

_start:                         # code entry point
    li      t0, 1
    li      t1, 2
    li      x31, 0
    bne     t0, t1, Exit
    addi    x31, x31, 1
    addi    x31, x31, 2
    
Exit:
    addi    x31, x31, 4
    addi    x31, x31, 8
    ebreak
    
