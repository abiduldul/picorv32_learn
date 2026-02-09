#include <stdint.h>
#include "tables.h"
#include "audio_data.h"

#define MAGIC_ADDR 0x00020000
// --- INLINE ASSEMBLY UNTUK CUSTOM INSTRUCTION ---
// Fungsi ini memanggil Hardware PCPI yang kita buat
static inline uint32_t fft_accel_cmd(uint32_t packed_data, uint32_t packed_twiddle) {
    uint32_t result;
    // .insn r (R-Type Instruction)
    // Opcode: 0x0B (Custom-0)
    // Func3: 0, Func7: 0
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2"
        : "=r"(result)              // Output (%0)
        : "r"(packed_data),         // Input 1 (%1)
          "r"(packed_twiddle)       // Input 2 (%2)
    );
    return result;
}

// --- FFT CORE YANG DIMODIFIKASI ---
void fft_core_accelerated(int32_t *real, int32_t *imag, int inverse) {
    int i, j, k;
    int32_t temp_r, temp_i;

    // Bit Reversal (Tetap Software - tidak berat)
    j = 0;
    for (i = 0; i < FFT_SIZE - 1; i++) {
        if (i < j) {
            temp_r = real[i]; real[i] = real[j]; real[j] = temp_r;
            temp_i = imag[i]; imag[i] = imag[j]; imag[j] = temp_i;
        }
        k = FFT_SIZE >> 1;
        while (k <= j) { j -= k; k >>= 1; }
        j += k;
    }

    // Butterfly Loop (BAGIAN INI KITA PERCEPAT!)
    int L, m, step;
    int32_t tr, ti; 
    
    // Variabel packing
    int16_t c_short, s_short, r_pair_short, i_pair_short;
    uint32_t packed_data, packed_twiddle, packed_result;
    int16_t res_tr_short, res_ti_short;

    for (L = 2; L <= FFT_SIZE; L <<= 1) {
        m = L >> 1;
        step = (FFT_SIZE / 2) / m; 
        for (j = 0; j < m; j++) {
            int idx = j * step;
            
            // Siapkan Twiddle Factor (Cos/Sin)
            // Pack ke dalam 32-bit: [Cos | Sin]
            c_short = (int16_t)CosTable[idx];
            s_short = (int16_t)SinTable[idx];
            
            // Logic IFFT (Inverse) merubah tanda Sin
            if (inverse) s_short = -s_short;

            packed_twiddle = ((uint32_t)c_short << 16) | ((uint32_t)s_short & 0xFFFF);

            for (i = j; i < FFT_SIZE; i += L) {
                int pair = i + m;

                // Siapkan Data Pair
                // Pack ke dalam 32-bit: [Real | Imag]
                r_pair_short = (int16_t)real[pair];
                i_pair_short = (int16_t)imag[pair];
                packed_data = ((uint32_t)r_pair_short << 16) | ((uint32_t)i_pair_short & 0xFFFF);

                // --- PANGGIL HARDWARE ACCELERATOR! ---
                // "Hardware, tolong hitung (R*C - I*S) dan (R*S + I*C)"
                packed_result = fft_accel_cmd(packed_data, packed_twiddle);

                // Unpack Hasil dari Hardware
                // [ Result Real | Result Imag ]
                res_tr_short = (int16_t)(packed_result >> 16);
                res_ti_short = (int16_t)(packed_result & 0xFFFF);

                tr = (int32_t)res_tr_short;
                ti = (int32_t)res_ti_short;
                
                // Update Array (Operasi penjumlahan sederhana tetap di software)
                real[pair] = real[i] - tr;
                imag[pair] = imag[i] - ti;
                real[i] = real[i] + tr;
                imag[i] = imag[i] + ti;
            }
        }
    }

    // Scaling (IFFT Only)
    if (inverse) {
        for (i = 0; i < FFT_SIZE; i++) {
            real[i] = real[i] >> LOG2_N; 
            imag[i] = imag[i] >> LOG2_N;
        }
    }
}

// --- FUNGSI MATH: 3-BAND EQ ---
void process_math_only(int32_t *chunk_real, int32_t *chunk_imag) {
    
    // 1. FFT
    fft_core_accelerated(chunk_real, chunk_imag, 0);

    // 2. EQUALIZER (3 BANDS)
    // Definisi Area Frekuensi (Simetris!)
    // 0 - 4   : BASS
    // 5 - 16  : MID
    // 17 - 32 : TREBLE
    // Dan cerminnya...
    
    int32_t gain;

    for(int i = 0; i < FFT_SIZE; i++) {
        // Normalisasi index untuk simetri (mirroring)
        // Jika i > 32 (setengah N), lihat cerminnya
        int idx_checked = (i > FFT_SIZE/2) ? (FFT_SIZE - i) : i;

        if (idx_checked <= 4) {
            // --- BASS AREA ---
            gain = 2048; // Boost 2.0x
        } 
        else if (idx_checked <= 16) {
            // --- MID AREA ---
            gain = 512;  // Cut 0.5x
        } 
        else {
            // --- TREBLE AREA ---
            gain = 256;  // Cut 0.25x
        }

        // Apply Gain
        chunk_real[i] = (chunk_real[i] * gain) >> FIXED_SHIFT;
        chunk_imag[i] = (chunk_imag[i] * gain) >> FIXED_SHIFT;
    }

    // 3. IFFT
    fft_core_accelerated(chunk_real, chunk_imag, 1);
}

int main() {
    volatile int32_t *output_stream = (volatile int32_t*) MAGIC_ADDR;

    // Buffer System
    int32_t buffer_real[FFT_SIZE];
    int32_t buffer_imag[FFT_SIZE];
    int buffer_index = 0;

    // MAIN LOOP
    for (int i = 0; i < AUDIO_LEN; i++) { 
        // 1. Fill Buffer
        buffer_real[buffer_index] = audio_data[i];
        buffer_imag[buffer_index] = 0;
        buffer_index++;

        // 2. Jika Penuh, Proses!
        if (buffer_index == FFT_SIZE) {
            
            // A. Lakukan Matematika (FFT -> EQ -> IFFT)
            process_math_only(buffer_real, buffer_imag);
            
            // B. Lakukan Printing DI SINI (Di dalam Main)
            // Agar pointer output_stream bergerak linear
            for (int k = 0; k < FFT_SIZE; k++) {
                *output_stream++ = buffer_real[k];
            }
            
            // Reset Index
            buffer_index = 0;
        }
    }

    asm volatile ("ebreak");
    while(1);
    return 0;
}