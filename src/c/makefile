CC			= riscv32-unknown-elf-gcc
OBJDUMP		= riscv32-unknown-elf-objdump
OBJCOPY		= riscv32-unknown-elf-objcopy
SIZE		= riscv32-unknown-elf-size
HEXDUMP		= hexdump
XXD			= xxd
MACH		= rv32i
MABI		= ilp32
CFLAGS		= -O0 -g -c --specs=nosys.specs -Wall -march=$(MACH) -mabi=$(MABI) -mmshift
LDFLAGS	= -O0 -g -nostartfiles --specs=nosys.specs -march=$(MACH) -mabi=$(MABI) -Wl,-T,sections.lds,-Map,program.map

all: clean main.o boot.o ram_init.o program.elf program.elf.objdump program.elf.lst program.bin program.hex size program.v

main.o:main.c
	$(CC) $(CFLAGS) -o $@ $^

boot.o:boot.S
	$(CC) $(CFLAGS) -o $@ $^

ram_init.o:ram_init.c
	$(CC) $(CFLAGS) -o $@ $^
	
program.elf:boot.o ram_init.o main.o
	$(CC) $(LDFLAGS) -o $@ $^
	
program.elf.objdump:program.elf
	$(OBJDUMP) -D $^ > $@

program.elf.lst:program.elf
	$(OBJDUMP) -h $^ > $@

program.bin:program.elf
	$(OBJCOPY) -O binary $^ $@

# program.h:program.bin
# 	# $(XXD) -i $^ > $@

program.hex: program.bin
	$(HEXDUMP) -ve '1/4 "%08x\n"' $^ > $@

program.v: program.hex
	# python3 hex_to_verilog.py $^
	python3 update_axi_rom.py $^ ../../rtl/axi_rom.v
	python3 hex_to_coe.py $^ program.coe
	
size:program.elf
	$(SIZE) $^
	
clean:
	rm -rf *.o *.elf *.objdump *.lst *.map *.bin *.hex *.v program.h main