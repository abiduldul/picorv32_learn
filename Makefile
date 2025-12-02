######### WINDOWS #############
# .PHONY: sim clean wave ass build flash

# # default top module
# TOP 		?= picorv32_system

# # define tools #
# IVERILOG 	= iverilog
# VVP 		= vvp
# VIVADO		= vivado -mode batch -source

# # directory structure #
# RTL 		= rtl
# TB 			= tb
# SIM 		= sim
# SRC 		= src
# TCL 		= viv/tcl
# XDC 		= viv/xdc
# RES 		= viv/res
# LOG 		= viv/out/log

# # include file #
# INC 		= $(RTL)/include.vh

# # source files #
# DSG 		= $(INC) $(RTL)/$(TOP).v $(TB)/tb_$(TOP).v
# OUT 		= $(SIM)/tb_$(TOP).vvp
# VCD 		= $(SIM)/tb_$(TOP).vcd

# # === OS-specific command definitions ===
# # Detect if the OS is Windows NT (cmd.exe)
# ifeq ($(OS),Windows_NT)
#     RM       = del /Q /F
#     RMDIR    = rmdir /S /Q
#     WAVE_CMD = gtkwave $(VCD)
#     MKDIR_P  = if not exist $(subst /,\,$(1)) mkdir $(subst /,\,$(1))
#     # Convert paths for Windows commands
#     OUT_PATH = $(subst /,\,$(OUT))
#     SIM_PATH = $(subst /,\,$(SIM))
# else
# # Assume Linux/Unix-like shell
#     RM       = rm -f
#     RMDIR    = rm -rf
#     WAVE_CMD = gtkwave $(VCD) &
#     MKDIR_P  = mkdir -p $(1)
#     # No path conversion needed
#     OUT_PATH = $(OUT)
#     SIM_PATH = $(SIM)
# endif

# # pattern rule #
# %:
# 	@$(MAKE) TOP=$@ $(MAKECMDGOALS)

# sim:
# 	$(IVERILOG) -o $(OUT) $(DSG)
# 	$(VVP) $(OUT)

# wave: $(VCD)
# 	$(WAVE_CMD)


# # === assembly section ===
# ROM_HEX     = $(SRC)/hex/

# CROSS_COMPILE ?= riscv-none-elf-

# AS      	= $(CROSS_COMPILE)as
# LD      	= $(CROSS_COMPILE)ld
# OBJCOPY 	= $(CROSS_COMPILE)objcopy
# HEXDUMP 	= hexdump

# LDFLAGS 	= -Ttext=0x00000000
# HEXFLAGS 	= -ve '1/4 "%08x\n"'

# # Filter known targets to get the assembly filename (e.g., 'fib' from 'make ass fib')
# ASS_TARGET_FILE := $(filter-out ass sim wave clean all build flash, $(MAKECMDGOALS))

# # If no filename is given with 'ass', print usage. Otherwise, 'ass' depends on the given filename.
# ifeq ($(strip $(ASS_TARGET_FILE)),)
# ass:
# 	@echo "usage: make ass <filename> (e.g. make ass fib)"
# 	@echo "Error: No filename specified."
# 	@exit 1
# else
# ass: $(ASS_TARGET_FILE)

# # Mark the dynamic filename target as phony so 'make' doesn't look for a file with that name
# .PHONY: $(ASS_TARGET_FILE)
# endif

# # Generic rule to assemble any .s file. This is triggered when 'ass' depends on a filename.
# $(ASS_TARGET_FILE):
# 	@echo "--- Assembling $(SRC)/$@.s ---"
# 	@$(call MKDIR_P, $(ROM_HEX))
# 	$(AS) $(SRC)/$@.s -o temp.o
# 	$(LD) $(LDFLAGS) temp.o -o temp.elf
# 	$(OBJCOPY) -O binary temp.elf temp.bin
# 	python $(SRC)/bin_to_hex.py temp.bin > $(ROM_HEX)$@.hex
# 	-$(RM) temp.o temp.elf temp.bin
# 	@echo "--- assembly successful ---"
# 	@echo "source:  $(SRC)/$@.s"
# 	@echo "output:  $(ROM_HEX)$@.hex\n"


# # === vivado section ===
# CLOG	= -log $(LOG)/vivado.log
# CJOU	= -journal $(LOG)/vivado.jou

# build:
# 	$(VIVADO) $(TCL)/build.tcl $(CLOG) $(CJOU)
# 	-$(RMDIR) .Xil

# flash:
# 	$(VIVADO) $(TCL)/flash.tcl $(CLOG) $(CJOU)


# # === clean section ===
# clean:
# 	-$(RM) $(OUT_PATH)
# 	-$(RM) $(SIM_PATH)\*.vcd

# # default target
# .DEFAULT_GOAL := sim


######### linux #############
# Makefile for Linux
.PHONY: sim clean wave ass build flash

# default top module
TOP         ?= picorv32_soc

# define tools #
IVERILOG    = iverilog
VVP         = vvp
VIVADO      = vivado -mode batch -source
PYTHON      = python # Ganti ke python3 jika 'python' tidak ada di sistem Anda

# directory structure #
RTL         = rtl
TB          = tb
SIM         = sim
SRC         = src
TCL         = viv/tcl
XDC         = viv/xdc
RES         = viv/res
LOG         = viv/out/log
ROM_HEX     = $(SRC)/hex

# include file #
INC         = $(RTL)/include.vh

# source files #
DSG         = $(INC) $(RTL)/$(TOP).v $(TB)/tb_$(TOP).v
OUT         = $(SIM)/tb_$(TOP).vvp
VCD         = $(SIM)/tb_$(TOP).vcd

# === Linux command definitions ===
RM          = rm -f
RMDIR       = rm -rf
WAVE_CMD    = gtkwave $(VCD) &
# Fungsi untuk membuat direktori
MKDIR_P     = mkdir -p $(1)

# pattern rule #
%:
	@$(MAKE) TOP=$@ $(MAKECMDGOALS)

sim:
	$(IVERILOG) -o $(OUT) $(DSG)
	$(VVP) $(OUT)

wave: $(VCD)
	$(WAVE_CMD)


# === assembly section ===
CROSS_COMPILE ?= riscv-none-elf-

AS          = $(CROSS_COMPILE)as
LD          = $(CROSS_COMPILE)ld
OBJCOPY     = $(CROSS_COMPILE)objcopy
HEXDUMP     = hexdump

LDFLAGS     = -Ttext=0x00000000
HEXFLAGS    = -ve '1/4 "%08x\n"'

# Filter known targets to get the assembly filename (e.g., 'fib' from 'make ass fib')
ASS_TARGET_FILE := $(filter-out ass sim wave clean all build flash, $(MAKECMDGOALS))

# If no filename is given with 'ass', print usage. Otherwise, 'ass' depends on the given filename.
ifeq ($(strip $(ASS_TARGET_FILE)),)
ass:
	@echo "usage: make ass <filename> (e.g. make ass fib)"
	@echo "Error: No filename specified."
	@exit 1
else
ass: $(ASS_TARGET_FILE)

# Mark the dynamic filename target as phony so 'make' doesn't look for a file with that name
.PHONY: $(ASS_TARGET_FILE)
endif

# Generic rule to assemble any .s file. This is triggered when 'ass' depends on a filename.
$(ASS_TARGET_FILE):
	@echo "--- Assembling $(SRC)/$@.s ---"
	@$(call MKDIR_P, $(ROM_HEX))
	$(AS) $(SRC)/$@.s -o temp.o
	$(LD) $(LDFLAGS) temp.o -o temp.elf
	$(OBJCOPY) -O binary temp.elf temp.bin
	$(PYTHON) $(SRC)/bin_to_hex.py temp.bin > $(ROM_HEX)$@.hex
	-$(RM) temp.o temp.elf temp.bin
	@echo "--- assembly successful ---"
	@echo "source:  $(SRC)/$@.s"
	@echo "output:  $(ROM_HEX)$@.hex\n"


# === vivado section ===
CLOG    = -log $(LOG)/vivado.log
CJOU    = -journal $(LOG)/vivado.jou

build:
	@$(call MKDIR_P, $(LOG))
	$(VIVADO) $(TCL)/build.tcl $(CLOG) $(CJOU)

flash:
	@$(call MKDIR_P, $(LOG))
	$(VIVADO) $(TCL)/flash.tcl $(CLOG) $(CJOU)


# === clean section ===
clean:
	-$(RM) $(OUT)
	-$(RM) $(SIM)/*.vcd
	-$(RM) $(LOG)/*
	-$(RM) clockInfo.txt
	-$(RM) dfx_runtime.txt
	-$(RMDIR) .Xil
	-$(RMDIR) viv/out # Hapus direktori log jika kosong
	-$(RMDIR) $(ROM_HEX) # Hapus direktori hex jika kosong

# default target
.DEFAULT_GOAL := sim