import sys
import os


def hex_to_verilog(input_file, output_file):
    try:
        with open(input_file, "r") as f:
            lines = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Error: Input file not found at '{input_file}'")
        return

    with open(output_file, "w") as f:
        f.write("initial begin\n")
        for i, line in enumerate(lines):
            f.write(f"    mem[{i}] = 32'h{line};\n")
        f.write("end\n")


if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        sys.exit(1)

    input_filename = sys.argv[1]

    if len(sys.argv) == 3:
        output_filename = sys.argv[2]
    else:
        base_name = os.path.splitext(input_filename)[0]
        output_filename = base_name + ".v"

    hex_to_verilog(input_filename, output_filename)
