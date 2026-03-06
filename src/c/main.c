#include <stdint.h>
#include "tables.h"
#include "audio_data.h"

#define MAGIC_ADDR 0x00020000

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

    // 2. Butterfly
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
                    tr = (real[pair] * c - imag[pair] * s) >> FIXED_SHIFT;
                    ti = (real[pair] * s + imag[pair] * c) >> FIXED_SHIFT;
                } else {
                    tr = (real[pair] * c + imag[pair] * s) >> FIXED_SHIFT;
                    ti = (imag[pair] * c - real[pair] * s) >> FIXED_SHIFT;
                }
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