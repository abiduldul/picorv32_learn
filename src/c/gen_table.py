# HOW TO USE:
# python3 gen_table.py > tables.h

import math

# --- KONFIGURASI ---
FFT_SIZE = 64       # Ukuran FFT (harus pangkat 2)
FIXED_SHIFT = 10    # Q10 Format
SCALE = 1 << FIXED_SHIFT

# Hitung Log2(N) untuk keperluan shifting di C nanti
LOG2_N = int(math.log2(FFT_SIZE))

print(f"#ifndef TABLES_H")
print(f"#define TABLES_H")
print(f"")
print(f"#include <stdint.h>")
print(f"")
print(f"#define FFT_SIZE {FFT_SIZE}")
print(f"#define FIXED_SHIFT {FIXED_SHIFT}")
print(f"#define LOG2_N {LOG2_N}  // Untuk scaling IFFT (div by N)")
print(f"")

# Generate Sin/Cos Tables (Setengah lingkaran sudah cukup)
print(f"// Tabel Sin/Cos untuk N={FFT_SIZE}")
print(f"// Sudut 0 sampai Pi (N/2 sample)")
print(f"const int16_t SinTable[{FFT_SIZE // 2}] = {{")
sins = []
coss = []

for i in range(FFT_SIZE // 2):
    # Sudut positif. Nanti di C kita atur +/- nya.
    angle = 2 * math.pi * i / FFT_SIZE
    
    val_sin = int(math.sin(angle) * SCALE)
    val_cos = int(math.cos(angle) * SCALE)
    
    sins.append(str(val_sin))
    coss.append(str(val_cos))

print("    " + ", ".join(sins))
print("};")
print("")

print(f"const int16_t CosTable[{FFT_SIZE // 2}] = {{")
print("    " + ", ".join(coss))
print("};")
print(f"")
print(f"#endif")