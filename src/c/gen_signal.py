# python3 gen_signal.py > audio_data.h
import math

# KONFIGURASI
AUDIO_LEN = 1024   # Kelipatan 64 terdekat dari 1000
N = 64
AMPLITUDE = 1000

# Definisi 3 Frekuensi ( f = bin × (sample_rate / N))
# Bin 2 = Bass --> f = 2 × (8000 / 64) = 250 Hz
# Bin 10 = Mid --> f = 10 × (8000 / 64) = 1250 Hz
# Bin 24 = Treble --> f = 24 × (8000 / 64) = 3000 Hz

FREQ_BASS = 2 
FREQ_MID = 10
FREQ_TREBLE = 24

print(f"// 3-Tone Signal: Bass -> Mid -> Treble (Total {AUDIO_LEN})")
print(f"#define AUDIO_LEN {AUDIO_LEN}")
print(f"const int32_t audio_data[{AUDIO_LEN}] = {{")

values = []
for i in range(AUDIO_LEN):
    val = 0
    
    # BAGI MENJADI 3 ZONA
    if i < 341:
        # Zona 1: BASS
        theta = 2 * math.pi * FREQ_BASS * i / N
        val = AMPLITUDE * math.cos(theta)
    elif i < 682:
        # Zona 2: MID
        theta = 2 * math.pi * FREQ_MID * i / N
        val = AMPLITUDE * math.cos(theta)
    else:
        # Zona 3: TREBLE
        theta = 2 * math.pi * FREQ_TREBLE * i / N
        val = AMPLITUDE * math.cos(theta)
        
    values.append(str(int(val)))

# Format output agar rapi (10 angka per baris)
for i in range(0, len(values), 10):
    print("    " + ", ".join(values[i:i+10]) + ",")

print("};")