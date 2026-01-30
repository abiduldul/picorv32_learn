# HOW TO USE :
# python3 audio_tool.py input terompet.wav

import numpy as np
from scipy.io import wavfile
import sys
import math

# KONFIGURASI
FFT_SIZE = 64
FIXED_SHIFT = 10    # Sesuai C code (Q10)

def wav_to_c_header(wav_filename, output_header="audio_data.h"):
    print(f"--- Converting {wav_filename} to C Header ---")
    
    # 1. Baca WAV
    samplerate, data = wavfile.read(wav_filename)
    print(f"Sample Rate: {samplerate} Hz")
    
    # 2. Cek Mono/Stereo
    if len(data.shape) > 1:
        print("Stereo detected, converting to Mono...")
        data = data.mean(axis=1).astype(int)
    else:
        print("Mono file detected.")

    # 3. Normalisasi/Safety Check
    # Pastikan data dalam format integer yang aman (misal 16-bit range)
    # Jika WAV float (-1.0 s/d 1.0), kita harus scaling.
    # Asumsi: WAV standar PCM 16-bit (-32768 s/d 32767)
    
    # 4. Padding (Agar pas dengan kelipatan FFT_SIZE)
    original_len = len(data)
    remainder = original_len % FFT_SIZE
    if remainder != 0:
        padding = FFT_SIZE - remainder
        data = np.pad(data, (0, padding), 'constant')
        print(f"Added {padding} zeros for padding.")
    
    total_len = len(data)
    print(f"Total Samples: {total_len} (Original: {original_len})")

    # 5. Tulis ke Header File
    with open(output_header, "w") as f:
        f.write(f"// Converted from {wav_filename}\n")
        f.write(f"#include <stdint.h>\n\n")
        f.write(f"#define AUDIO_LEN {total_len}\n")
        f.write(f"const int32_t audio_data[{total_len}] = {{\n")
        
        # Tulis data per baris biar rapi
        for i in range(0, total_len, 10):
            chunk = data[i:i+10]
            line = ", ".join(map(str, chunk))
            f.write(f"    {line},\n")
            
        f.write("};\n")
    
    print(f"Success! Saved to {output_header}")
    print(f"Copy this file to your C project folder.\n")

def txt_to_wav(txt_filename, output_wav="processed.wav", samplerate=22050):
    print(f"--- Converting {txt_filename} to WAV ---")
    
    values = []
    try:
        with open(txt_filename, "r") as f:
            for line in f:
                line = line.strip()
                # Filter marker (angka seperti 1111, 5555, 7777)
                # Cara sederhana: Kita anggap audio range -32000 s/d 32000.
                # Marker biasanya angka aneh atau urutan tertentu.
                # TAPI, metode terbaik di sistem Anda:
                # C code Anda mencetak Marker 5555 LALU data.
                # Kita bisa skip marker manual atau filter angka.
                
                # Logic: Ambil semua angka, nanti kita potong marker kalau terdengar 'klik'
                try:
                    val = int(line)
                    # Filter marker visual yang kita buat (1111, 5555, 7777, 8888, 9999)
                    if val in [1111, 5555, 7777, 8888, 9999]: 
                        continue 
                    values.append(val)
                except ValueError:
                    pass
    except FileNotFoundError:
        print("Error: Output text file not found.")
        return

    # Convert ke Numpy Array
    audio_data = np.array(values, dtype=np.int16)
    
    # Tulis ke WAV
    wavfile.write(output_wav, samplerate, audio_data)
    print(f"Success! Saved to {output_wav}")
    print(f"Samples written: {len(audio_data)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  To Convert WAV -> Header:  python audio_tool.py input input_file.wav")
        print("  To Convert TXT -> WAV:     python audio_tool.py output output_samples.txt")
    else:
        mode = sys.argv[1]
        file_path = sys.argv[2]
        
        if mode == "input":
            wav_to_c_header(file_path)
        elif mode == "output":
            txt_to_wav(file_path)
        else:
            print("Unknown mode. Use 'input' or 'output'.")