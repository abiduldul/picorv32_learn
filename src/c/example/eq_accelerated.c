#include <stdint.h>
#include "tables.h"
#include "audio_data.h"

#define MAGIC_ADDR 0x00020000

// ==============================================================================
// MAKRO HARDWARE: KOPROSESOR DSP STATEFUL (OPSI B)
// ==============================================================================
// hw_bsave       : Menyimpan (rs1 * rs2) ke dalam akumulator hardware 64-bit
// hw_bsub_shift  : Mengembalikan ((akumulator - (rs1 * rs2)) >> FIXED_SHIFT)
// hw_badd_shift  : Mengembalikan ((akumulator + (rs1 * rs2)) >> FIXED_SHIFT)

#define hw_bsave(rs1, rs2) \
    __asm__ volatile ("bsave %0, %1" : : "r"(rs1), "r"(rs2))

#define hw_bsub_shift(rd, rs1, rs2) \
    __asm__ volatile ("bsub_shift %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

#define hw_badd_shift(rd, rs1, rs2) \
    __asm__ volatile ("badd_shift %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
// ==============================================================================

void fft_core(int32_t *real, int32_t *imag, int inverse) {
    int i, j, k;
    int32_t temp_r, temp_i;

    // 1. Bit Reversal
    j = 0;
    for (i = 0; i < FFT_SIZE - 1; i++) {
        if (i < j) {
            temp_r = real[i]; real[i] = real[j]; real[j] = temp_r;
            temp_i = imag[i]; imag[i] = imag[j]; imag[j] = temp_i;
        }
        k = FFT_SIZE >> 1;
        while (k <= j && k > 0) { j -= k; k >>= 1; }
        j += k;
    }

    // 2. Butterfly (HARDWARE ACCELERATED)
    int L, m, step;
    int32_t tr, ti; 
    int16_t c, s;

    for (L = 2; L <= FFT_SIZE; L <<= 1) {
        m = L >> 1;
        step = (FFT_SIZE / 2) / m; 
        for (j = 0; j < m; j++) {
            int idx = j * step;
            c = CosTable[idx];
            s = SinTable[idx];
            for (i = j; i < FFT_SIZE; i += L) {
                int pair = i + m;
                
                if (inverse == 0) {
                    // --- FORWARD FFT ---
                    // tr = (real[pair] * c - imag[pair] * s) >> FIXED_SHIFT;
                    hw_bsave(real[pair], c);
                    hw_bsub_shift(tr, imag[pair], s);
                    
                    // ti = (real[pair] * s + imag[pair] * c) >> FIXED_SHIFT;
                    hw_bsave(real[pair], s);
                    hw_badd_shift(ti, imag[pair], c);
                } else {
                    // --- INVERSE FFT (IFFT) ---
                    // tr = (real[pair] * c + imag[pair] * s) >> FIXED_SHIFT;
                    hw_bsave(real[pair], c);
                    hw_badd_shift(tr, imag[pair], s);
                    
                    // ti = (imag[pair] * c - real[pair] * s) >> FIXED_SHIFT;
                    // Perhatikan urutannya: Simpan (imag*c) ke hardware, lalu kurangi dengan (real*s)
                    hw_bsave(imag[pair], c);
                    hw_bsub_shift(ti, real[pair], s);
                }
                
                // Aplikasikan hasil
                real[pair] = real[i] - tr;
                imag[pair] = imag[i] - ti;
                real[i] = real[i] + tr;
                imag[i] = imag[i] + ti;
            }
        }
    }

    // 3. Scaling (IFFT Only)
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
    fft_core(chunk_real, chunk_imag, 0);

    // 2. EQUALIZER (3 BANDS)
    int32_t gain;

    for(int i = 0; i < FFT_SIZE; i++) {
        // Normalisasi index untuk simetri (mirroring)
        int idx_checked = (i > FFT_SIZE/2) ? (FFT_SIZE - i) : i;

        if (idx_checked <= 4) {
            gain = 2048; // BASS: Boost 2.0x
        } 
        else if (idx_checked <= 16) {
            gain = 512;  // MID: Cut 0.5x
        } 
        else {
            gain = 256;  // TREBLE: Cut 0.25x
        }

        // Apply Gain (Otomatis ditangani oleh "mshift" di riscv.md karena kita tidak mengubah GCC optimization)
        chunk_real[i] = (chunk_real[i] * gain) >> FIXED_SHIFT;
        chunk_imag[i] = (chunk_imag[i] * gain) >> FIXED_SHIFT;
    }

    // 3. IFFT
    fft_core(chunk_real, chunk_imag, 1);
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
            
            // B. Lakukan Printing
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