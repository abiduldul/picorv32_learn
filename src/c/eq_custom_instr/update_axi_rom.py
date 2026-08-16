import sys
import os

def update_rom_file(hex_file, verilog_file):
    # 1. READ THE HEX FILE
    try:
        with open(hex_file, "r") as f:
            hex_lines = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Error: Hex file not found at '{hex_file}'")
        return

    # 2. GENERATE NEW VERILOG INITIALIZATION BLOCK
    # This mimics your hex_to_verilog.py logic
    new_block_lines = []
    new_block_lines.append("initial begin\n")
    for i, line in enumerate(hex_lines):
        new_block_lines.append(f"    mem[{i}] = 32'h{line};\n")
    new_block_lines.append("end\n")

    # 3. READ THE TARGET VERILOG FILE
    try:
        with open(verilog_file, "r") as f:
            verilog_lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: Verilog file not found at '{verilog_file}'")
        return

    # 4. FIND START AND END MARKERS IN AXI_ROM.V
    start_index = -1
    end_index = -1
    
    # We look for the 'initial begin' that comes specifically after '// ROM initialization'
    # to avoid deleting other initial blocks if they exist.
    rom_init_found = False
    
    for i, line in enumerate(verilog_lines):
        # Detect the section header
        if "// ROM initialization" in line:
            rom_init_found = True
        
        # Find the 'initial begin' strictly after the header
        if rom_init_found and "initial begin" in line:
            start_index = i
            break
            
    if start_index == -1:
        print("Error: Could not find 'initial begin' block after '// ROM initialization' in verilog file.")
        return

    # Find the matching 'end' for this block
    # We assume standard formatting where 'end' is on its own line or at start of line
    for i in range(start_index, len(verilog_lines)):
        if "end" in verilog_lines[i].strip() and verilog_lines[i].strip() == "end":
            end_index = i
            break
            
    if end_index == -1:
        print("Error: Could not find closing 'end' tag for the ROM block.")
        return

    # 5. RECONSTRUCT THE FILE CONTENT
    # Keep lines before the block + New Block + Keep lines after the block
    final_lines = verilog_lines[:start_index] + new_block_lines + verilog_lines[end_index+1:]

    # 6. WRITE BACK TO FILE
    with open(verilog_file, "w") as f:
        f.writelines(final_lines)

    print(f"Successfully updated {verilog_file} with {len(hex_lines)} words from {hex_file}.")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python update_axi_rom.py <input.hex> <target_axi_rom.v>")
        print("Example: python update_axi_rom.py firmware.hex rtl/axi_rom.v")
        sys.exit(1)

    input_hex = sys.argv[1]
    target_verilog = sys.argv[2]

    update_rom_file(input_hex, target_verilog)