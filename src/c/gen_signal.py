# HOW TO USE:
# python3 gen_signal.py > input_data.h

import math

N = 64
AMPLITUDE_BASS = 1000
AMPLITUDE_TREBLE = 500

# Kita pakai frekuensi yang "pas" dengan Bin FFT agar angkanya cantik
# Bin 2 = 2 putaran per window
# Bin 20 = 20 putaran per window
FREQ_BASS = 2 
FREQ_TREBLE = 20

print(f"// Input Signal: Bass (Bin {FREQ_BASS}, Amp {AMPLITUDE_BASS}) + Treble (Bin {FREQ_TREBLE}, Amp {AMPLITUDE_TREBLE})")
print(f"const int32_t mixed_input[{N}] = {{")

values = []
for i in range(N):
    # Rumus: A1*cos(2*pi*f1*t) + A2*cos(2*pi*f2*t)
    theta_bass = 2 * math.pi * FREQ_BASS * i / N
    theta_treble = 2 * math.pi * FREQ_TREBLE * i / N
    
    val = (AMPLITUDE_BASS * math.cos(theta_bass)) + (AMPLITUDE_TREBLE * math.cos(theta_treble))
    values.append(str(int(val)))

print("    " + ", ".join(values))
print("};")