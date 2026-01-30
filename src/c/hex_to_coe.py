import sys
import os

def hex_to_coe(input_hex_path, output_coe_path):
    print(f"Converting {input_hex_path} to {output_coe_path}...")
    
    try:
        # 1. Baca semua baris dari file Hex
        with open(input_hex_path, 'r') as f_in:
            # Ambil baris, hilangkan whitespace, dan filter baris kosong
            # Juga filter baris yang dimulai dengan '@' (address marker dari objcopy)
            lines = [line.strip() for line in f_in if line.strip() and not line.startswith('@')]

        if not lines:
            print("Error: Input file is empty or invalid.")
            return

        # 2. Tulis ke file COE
        with open(output_coe_path, 'w') as f_out:
            # Header Wajib Vivado
            f_out.write("memory_initialization_radix=16;\n")
            f_out.write("memory_initialization_vector=\n")
            
            # Tulis data
            total_lines = len(lines)
            for i, line in enumerate(lines):
                # Bersihkan "0x" jika ada
                clean_hex = line.replace("0x", "").lower()
                
                # Format: Data dipisah koma, data terakhir pakai titik koma
                if i < total_lines - 1:
                    f_out.write(f"{clean_hex},\n")
                else:
                    f_out.write(f"{clean_hex};\n") # Akhiran wajib
                    
        print(f"Success! COE file generated with {total_lines} words.")
        print("You can now load this into Vivado Block Memory Generator.")

    except FileNotFoundError:
        print(f"Error: File {input_hex_path} not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python hex_to_coe.py <input_file.hex> [output_file.coe]")
    else:
        input_file = sys.argv[1]
        
        # Jika nama output tidak diberikan, gunakan nama input dengan ekstensi .coe
        if len(sys.argv) >= 3:
            output_file = sys.argv[2]
        else:
            base_name = os.path.splitext(input_file)[0]
            output_file = base_name + ".coe"
            
        hex_to_coe(input_file, output_file)