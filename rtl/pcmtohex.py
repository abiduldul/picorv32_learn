import struct
import argparse

def pcm_to_hex(input_file, output_file, word_width=32):
    """
    Converts a binary PCM file into a Verilog readmemh-compatible hex file.

    Parameters:
        input_file (str): Path to the binary PCM file.
        output_file (str): Path to the output hex file.
        word_width (int): Width of the memory word in bits (e.g., 16, 32, 64).
    """
    # Number of PCM samples (16-bit) per memory word
    samples_per_word = word_width // 16

    with open(input_file, "rb") as pcm_file, open(output_file, "w") as hex_file:
        # Read the binary PCM file as 16-bit signed integers
        data = pcm_file.read()
        pcm_samples = struct.unpack(f"<{len(data) // 2}h", data)  # Little-endian 16-bit integers

        # Process samples into memory words
        for i in range(0, len(pcm_samples), samples_per_word):
            # Combine samples into a single memory word (padded with 0 if not enough samples)
            word_samples = pcm_samples[i:i + samples_per_word]
            word = 0
            for sample in word_samples:
                word = (word << 16) | (sample & 0xFFFF)  # Pack samples into memory word
            # Write the memory word as hex
            hex_file.write(f"{word:0{word_width // 4}X}\n")  # Hex with leading zeroes

    print(f"Hex file written to {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert PCM file to Verilog readmemh hex file.")
    parser.add_argument("input_file", help="Path to the input binary PCM file.")
    parser.add_argument("output_file", help="Path to the output hex file.")
    parser.add_argument("--word_width", type=int, default=32, help="Width of the memory word in bits (default: 32).")
    args = parser.parse_args()

    pcm_to_hex(args.input_file, args.output_file, args.word_width)