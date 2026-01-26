#include <stdint.h>
#include "tables.h"
#include "input_data.h"

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
        while (k <= j) { j -= k; k >>= 1; }
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

void process_chunk(int32_t *chunk_real, int32_t *chunk_imag, volatile int32_t *out_port) {
    
    // 1. FFT
    fft_core(chunk_real, chunk_imag, 0);

    // 2. EQUALIZER (Simple Bass Boost Logic)
    int limit_low = FFT_SIZE / 4;        
    int limit_high = FFT_SIZE - limit_low; 
    int32_t gain;

    for(int i = 0; i < FFT_SIZE; i++) {
        if (i < limit_low || i > limit_high) {
            gain = 2048; // Bass Boost 2x
        } else {
            gain = 256;  // Treble Cut 0.25x
        }
        chunk_real[i] = (chunk_real[i] * gain) >> FIXED_SHIFT;
        chunk_imag[i] = (chunk_imag[i] * gain) >> FIXED_SHIFT;
    }

    // 3. IFFT
    fft_core(chunk_real, chunk_imag, 1);

    // 4. Output Stream (Kirim hasil olahan ke luar)
    for (int i = 0; i < FFT_SIZE; i++) {
        *out_port++ = chunk_real[i];
    }
}

int main() {
    volatile int32_t *output_stream = (volatile int32_t*) MAGIC_ADDR;
    
    int32_t real[FFT_SIZE];
    int32_t imag[FFT_SIZE];

    // STEP 1: Input Signal
    for (int i = 0; i < FFT_SIZE; i++) {
        real[i] = mixed_input[i]; 
        imag[i] = 0;    
    }

    *output_stream++ = 1111; // START

    // STEP 2: FFT Forward
    fft_core(real, imag, 0); 

    *output_stream++ = 5555; // Marker "Pre-EQ Check"
    *output_stream++ = real[2];  // Cek Bass Asli (Harus ~32000 yaitu 1000*32)
    *output_stream++ = real[20]; // Cek Treble Asli (Harus ~16000 yaitu 500*32)
    // Catatan: FFT Real menghasilkan N/2 amplitude, jadi factor pengalinya 32, bukan 64.

    // ==========================================
    // STEP 3: DYNAMIC EQUALIZER
    // ==========================================
    int32_t gains[FFT_SIZE];

    // 1. Definisikan batas frekuensi (Bass vs Treble)
    // 0 s/d N/4       = Bass Area
    // N/4 s/d 3N/4    = Treble Area (Termasuk frekuensi negatif/cermin)
    // 3N/4 s/d N      = Bass Area (Cermin)
    
    int limit_low = FFT_SIZE / 4;        // Di N=64, ini index 16
    int limit_high = FFT_SIZE - limit_low; // Di N=64, ini index 48

    for(int i = 0; i < FFT_SIZE; i++) {
        if (i < limit_low || i > limit_high) {
            // BASS AREA (Termasuk DC di index 0)
            gains[i] = 2048; // Boost 2x
        } else {
            // TREBLE AREA
            gains[i] = 256;  // Cut signifikan (0.25x)
        }
    }
    
    // Terapkan Gain
    for (int i = 0; i < FFT_SIZE; i++) {
        real[i] = (real[i] * gains[i]) >> FIXED_SHIFT;
        imag[i] = (imag[i] * gains[i]) >> FIXED_SHIFT;
    }

    // --- DEBUG POINT SETELAH EQ ---
    *output_stream++ = 8888; // Marker "Post-EQ Check"
    *output_stream++ = real[2];  // Bass harus NAIK 2x (jadi ~64000)
    *output_stream++ = real[20]; // Treble harus TURUN 4x (jadi ~4000)

    // STEP 4: IFFT Inverse
    fft_core(real, imag, 1); 

    // STEP 5: Output
    *output_stream++ = 9999; 
    // Kita output 10 sample pertama saja agar file log tidak terlalu panjang
    // Tapi Anda bisa loop sampai FFT_SIZE jika mau lihat semua.
    for (int i = 0; i < 10; i++) {
        *output_stream++ = real[i];
    }
    *output_stream++ = 7777; 

    asm volatile ("ebreak");
    while(1);
    return 0;
}