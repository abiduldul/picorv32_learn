How to use
1. Buka terminal WSL dan ketik command 'make all' di src/c untuk clean inisialisasi program sebelumnya dan convert main.c to program.hex dan replace initial begin di axi_rom.v sesuai program main.c terbaru
2. ketik 'make clean' di src/c atau di picorv32_learn folder untuk membersihkan ulang file-file yang tidak digunakan dalam folder
3. ketik 'make sim' untuk mensimulasikan rtl berdasarkan testbench di folder tb

Ganti board FPGA :
1. Buka viv/tcl/set_variables.tcl
2. Ganti board_name dan fpga_part sesuai dengan board FPGA yang digunakan