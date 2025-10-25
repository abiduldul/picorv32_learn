.text
.align  2
.globl  _start

_start:
    lui     t0, 0x00000         # t0 = 0x00000000
    addi    t0, t0, 0x100       # t0 = 0x00000100
    
    li      x31, 3              # x31 = 3
    sw      x31, 0(t0)          # RAM[0x100] = 3

    addi    x31, x31, 10        # x31 = 13
    lw      x31, 0(t0)          # x31 = RAM[0x100] = 3

    addi    x31, x31, -1        # x31 = 2
    addi    x31, x31, -1        # x31 = 1

    ebreak

