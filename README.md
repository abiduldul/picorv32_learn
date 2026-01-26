How to use
1. Buka terminal WSL dan ketik command 'make all' untuk convert main.c to program.hex dan program.v
2. copy hex file program.v kedalam axi_rom.v secara manual agar software bisa dieksekusi oleh cpu picorv32
3. ketik 'make clean' untuk membersihkan ulang file-file yang tidak digunakan dalam folder c


Ganti board FPGA :
1. Buka viv/tcl/set_variables.tcl
2. Ganti board_name dan fpga_part sesuai dengan board FPGA yang digunakan

Reset boart Zynq Z-Lite --> active low
Reset boart Zynq Z-Lite --> active high