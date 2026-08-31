CC          = riscv32-unknown-elf-gcc
OBJDUMP     = riscv32-unknown-elf-objdump
OBJCOPY     = riscv32-unknown-elf-objcopy
SIZE        = riscv32-unknown-elf-size
MACH        = rv32i
MABI        = ilp32

CFLAGS      = -Os -g -c -ffreestanding -Wall -Wextra -march=$(MACH) -mabi=$(MABI)
LDFLAGS     = -Os -g -nostdlib -nostartfiles -march=$(MACH) -mabi=$(MABI) \
              -Wl,-T,sections.lds,-Map,program.map

HEADERS     = filter.h filter_coeff.h test_signal.h

all: clean $(HEADERS) main.o boot.o ram_init.o program.elf \
     program.elf.objdump program.bin program.hex size program.v

gen:
	python3 gen_test_signal.py
	python3 gen_filter_coeff.py

filter_coeff.h: test_signal.h
	python3 gen_filter_coeff.py

test_signal.h:
	python3 gen_test_signal.py

main.o: main.c $(HEADERS)
	$(CC) $(CFLAGS) -o $@ main.c

boot.o: boot.S
	$(CC) $(CFLAGS) -o $@ $^

ram_init.o: ram_init.c
	$(CC) $(CFLAGS) -o $@ $^

program.elf: boot.o ram_init.o main.o
	$(CC) $(LDFLAGS) -o $@ $^ -lgcc

program.elf.objdump: program.elf
	$(OBJDUMP) -D $^ > $@

program.bin: program.elf
	$(OBJCOPY) -O binary $^ $@

## the stock makefile uses hexdump; python is more portable
program.hex: program.bin
	python3 -c "import struct,sys; \
d=open('program.bin','rb').read(); \
d+=b'\x00'*((-len(d))%4); \
w=struct.unpack('<%dI'%(len(d)//4),d); \
open('program.hex','w').write(''.join('%08x\n'%x for x in w)); \
print('words:',len(w))"

program.v: program.hex
	python3 update_axi_rom.py program.hex ../../../rtl/axi_rom.v
# 	python3 ../eq_custom_instr/hex_to_coe.py program.hex program.coe

size: program.elf
	$(SIZE) $^

ROOT     = ../../..
IVERILOG = iverilog
VVP      = vvp

RTL_SOC  = $(ROOT)/rtl/picorv32_soc.v $(ROOT)/rtl/axi_rom.v $(ROOT)/rtl/axi_ram.v \
           $(ROOT)/rtl/axi4_lite_slave.v $(ROOT)/rtl/axi4_lite_interconnect_m1s4.v \
           $(ROOT)/rtl/filter/*.v \
           $(ROOT)/rtl/picorv32/picorv32_axi.v $(ROOT)/rtl/picorv32/picorv32.v \
           $(ROOT)/rtl/picorv32/picorv32_axi_adapter.v $(ROOT)/rtl/picorv32/picorv32_pcpi_*.v

sim: all
	$(IVERILOG) -g2012 -s tb_soc_filter -o /tmp/tb_soc_filter.vvp \
	    $(ROOT)/tb/tb_soc_filter.v $(RTL_SOC)
	cd $(ROOT) && $(VVP) /tmp/tb_soc_filter.vvp

sim-dump: all
	$(IVERILOG) -g2012 -o /tmp/tb_soc_dump.vvp \
	    $(ROOT)/tb/tb_picorv32_soc.v $(RTL_SOC)
	cd $(ROOT) && $(VVP) /tmp/tb_soc_dump.vvp

clean:
	rm -rf *.o *.elf *.objdump *.lst *.map *.bin *.hex program.v program.coe

distclean: clean
	rm -rf filter_coeff.h test_signal.h filter_coeff_ref.txt golden/

.PHONY: all gen clean distclean size sim sim-dump