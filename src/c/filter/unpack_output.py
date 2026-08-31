#!/usr/bin/env python3
"""
Unpack ../../../output_samples.txt (written by `make sim-dump`, one 32-bit
ram_output word per line) into the header fields plus one filtered sample
per line.

Layout, matching main.c:
  word 0  HDR_MAGIC    0xF117000X, X = preset actually loaded
  word 1  HDR_LEN      number of samples
  word 2  HDR_STATUS   0 = coefficients read back correctly
  word 3  (unused)
  word 4..  packed samples: low 16 bits = sample 2i, high 16 bits = sample 2i+1

Run:  python3 unpack_output.py [path/to/output_samples.txt]
"""
import sys


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "../../../output_samples.txt"
    with open(path) as f:
        lines = [line.strip() for line in f if line.strip()]

    # Only the header + the words main.c actually wrote are real numbers --
    # ram_output past that point was never touched by the firmware and its
    # words are still 'x' (uninitialized) in the Verilog dump.
    magic, length, status = (int(lines[i]) & 0xFFFFFFFF for i in range(3))
    print(f"HDR_MAGIC  = 0x{magic:08X}  (preset {magic & 0xFF})")
    print(f"HDR_LEN    = {length}")
    print(f"HDR_STATUS = {status}  (0 = coefficients read back correctly)")

    n_words = (length + 1) // 2
    data_words = [int(lines[4 + i]) & 0xFFFFFFFF for i in range(n_words)]

    samples = []
    for w in data_words:
        samples.append(s16(w & 0xFFFF))
        samples.append(s16((w >> 16) & 0xFFFF))
    samples = samples[:length]

    out_path = "filtered_samples.txt"
    with open(out_path, "w") as f:
        for v in samples:
            f.write(f"{v}\n")

    print(f"\n{len(samples)} samples -> {out_path}")
    print(f"min/max = {min(samples)} / {max(samples)}")
    print("first 12:", samples[:12])


if __name__ == "__main__":
    main()
