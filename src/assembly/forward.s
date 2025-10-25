.text
.align  2
.globl  _start

_start:                         # code entry point
    li      x31, 0
    li      t0, 1
    li      t1, 2
    li      t2, 3
    add     x31, x31, t2
    add     x31, x31, t2
    add     x31, x31, t1
    add     x31, x31, t0
    ebreak
