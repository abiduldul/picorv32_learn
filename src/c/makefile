CC			= riscv-none-elf-gcc
OBJDUMP		= riscv-none-elf-objdump
OBJCOPY		= riscv-none-elf-objcopy
SIZE		= riscv-none-elf-size
HEXDUMP		= hexdump
XXD			= xxd
MACH		= rv32im
MABI		= ilp32
CFLAGS		= -O0 -g -c --specs=nosys.specs -Wall -march=$(MACH)
LDFLAFGS	= -O0 -g -nostartfiles --specs=nosys.specs -march=$(MACH) -mabi=$(MABI) -Wl,-T,sections.lds,-Map,program.map
SPIKE		= -fno-common -fno-builtin-printf --specs=nano.specs --specs=nosys.specs -c main.c
LDSPIKE		= -static --specs=nano.specs --specs=nosys.specs main.o -o main.riscv

# all: clean main.o main.riscv boot.o ram_init.o main.o program.elf program.elf.objdump program.elf.lst program.bin program.h size program.hex program.v
all: clean main

main:main.c
	$(CC) $^ -o $@ -march=$(MACH) -mabi=$(MABI)

# main.riscv:main.o
# 	$(CC) $(LDSPIKE)

# main.o:main.c
# 	$(CC) $(CFLAGS) -o $@ $^

# boot.o:boot.S
# 	$(CC) $(CFLAGS) -o $@ $^

# ram_init.o:ram_init.c
# 	$(CC) $(CFLAGS) -o $@ $^
	
# program.elf:boot.o ram_init.o main.o
# 	$(CC) $(LDFLAFGS) -o $@ $^
	
# program.elf.objdump:program.elf
# 	$(OBJDUMP) -D $^ > $@

# program.elf.lst:program.elf
# 	$(OBJDUMP) -h $^ > $@

# program.bin:program.elf
# 	$(OBJCOPY) -O binary $^ $@

# program.h:program.bin
# 	# $(XXD) -i $^ > $@

# program.hex: program.bin
# 	$(HEXDUMP) -ve '1/4 "%08x\n"' $^ > $@

# program.v: program.hex
# 	# python3 hex_to_verilog.py $^
# 	python3 update_axi_rom.py $^ ../../rtl/axi_rom.v
# 	# python3 hex_to_coe.py $^ program.coe
	
# size:program.elf
# 	$(SIZE) $^
	
clean:
	rm -rf *.o *.elf *.objdump *.lst *.map *.bin *.hex *.v program.h main