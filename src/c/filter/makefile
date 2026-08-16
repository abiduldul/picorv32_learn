## Build the Butterworth filter demo instead of the FFT demo.
##
##   make -f makefile.filter gen     # regenerate coefficients + test signal
##   make -f makefile.filter all     # compile and patch ../../rtl/axi_rom.v
##
## Note: the stock makefile passes -mmshift, which only exists in the custom
## toolchain shipped with this repo.  This program does not need it -- plain
## rv32i is enough -- so it is left out here.  If your riscv32-unknown-elf-gcc
## is the custom one, adding -mmshift back is harmless.

CC          = riscv32-unknown-elf-gcc
OBJDUMP     = riscv32-unknown-elf-objdump
OBJCOPY     = riscv32-unknown-elf-objcopy
SIZE        = riscv32-unknown-elf-size
MACH        = rv32i
MABI        = ilp32

CFLAGS      = -Os -g -c --specs=nosys.specs -Wall -Wextra -march=$(MACH) -mabi=$(MABI)
LDFLAGS     = -Os -g -nostartfiles --specs=nosys.specs -march=$(MACH) -mabi=$(MABI) \
              -Wl,-T,sections.lds,-Map,program.map

HEADERS     = filter.h filter_coeff.h test_signal.h

all: clean $(HEADERS) main_filter.o boot.o ram_init.o program.elf \
     program.elf.objdump program.bin program.hex size program.v

## regenerate the two auto-generated headers
gen:
	python3 gen_filter_coeff.py
	python3 gen_test_signal.py

filter_coeff.h:
	python3 gen_filter_coeff.py

test_signal.h:
	python3 gen_test_signal.py

main_filter.o: main_filter.c $(HEADERS)
	$(CC) $(CFLAGS) -o $@ main_filter.c

boot.o: boot.S
	$(CC) $(CFLAGS) -o $@ $^

ram_init.o: ram_init.c
	$(CC) $(CFLAGS) -o $@ $^

program.elf: boot.o ram_init.o main_filter.o
	$(CC) $(LDFLAGS) -o $@ $^

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
	python3 update_axi_rom.py program.hex ../../rtl/axi_rom.v
	python3 hex_to_coe.py program.hex program.coe

size: program.elf
	$(SIZE) $^

clean:
	rm -rf *.o *.elf *.objdump *.lst *.map *.bin *.hex program.v program.coe

.PHONY: all gen clean size
