#include <stdint.h>
#include "tables.h"  // Semua definisi N dan Tabel ada di sini

#define MAGIC_ADDR 0x00020000

// Fungsi Inti FFT / IFFT
// inverse = 0: Forward FFT (Time -> Freq)
// inverse = 1: Inverse FFT (Freq -> Time)
void fft_core(int32_t *real, int32_t *imag, int inverse) {
    int i, j, k;
    int32_t temp_r, temp_i;

    // 1. BIT REVERSAL
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

    // 2. BUTTERFLY ENGINE
    int L, m, step;
    int32_t tr, ti; 
    int16_t c, s;

    for (L = 2; L <= FFT_SIZE; L <<= 1) {
        m = L >> 1;
        
        // Rumus Step Generik (Bekerja untuk N berapapun)
        // Kita punya tabel ukuran N/2. 
        // Jika m=1 (stage awal), kita butuh indeks 0, 8, ... (jika N=16)
        // Rumus: (Total_Tabel) / m
        step = (FFT_SIZE / 2) / m; 

        for (j = 0; j < m; j++) {
            // Ambil Twiddle Factor dari array eksternal
            int idx = j * step;
            c = CosTable[idx];
            s = SinTable[idx];

            for (i = j; i < FFT_SIZE; i += L) {
                int pair = i + m;

                // --- CORE LOGIC: FORWARD VS INVERSE ---
                if (inverse == 0) {
                    // Forward: Putar Clockwise (e^-j) -> (C - jS)
                    // Rumus: (Re*C - Im*S), (Re*S + Im*C)
                    tr = (real[pair] * c - imag[pair] * s) >> FIXED_SHIFT;
                    ti = (real[pair] * s + imag[pair] * c) >> FIXED_SHIFT;
                } else {
                    // Inverse: Putar Counter-Clockwise (e^j) -> (C + jS)
                    // Rumus: (Re*C + Im*S), (Im*C - Re*S)
                    tr = (real[pair] * c + imag[pair] * s) >> FIXED_SHIFT;
                    ti = (imag[pair] * c - real[pair] * s) >> FIXED_SHIFT;
                }

                // Update Wings
                real[pair] = real[i] - tr;
                imag[pair] = imag[i] - ti;
                real[i] = real[i] + tr;
                imag[i] = imag[i] + ti;
            }
        }
    }

    // 3. SCALING (KHUSUS IFFT)
    // Bagi hasil dengan N agar amplitudo kembali normal.
    // Kita gunakan shift right sebanyak LOG2_N (dari tables.h)
    if (inverse) {
        for (i = 0; i < FFT_SIZE; i++) {
            real[i] = real[i] >> LOG2_N; 
            imag[i] = imag[i] >> LOG2_N;
        }
    }
}

int main() {
    volatile int32_t *output_stream = (volatile int32_t*) MAGIC_ADDR;
    
    int32_t real[FFT_SIZE];
    int32_t imag[FFT_SIZE];

    // ==========================================
    // STEP 1: Input Generation (DC Signal)
    // ==========================================
    // Semua input = 1000
    for (int i = 0; i < FFT_SIZE; i++) {
        real[i] = 1000; 
        imag[i] = 0;    
    }

    *output_stream++ = 1111; // MARKER: START

    // ==========================================
    // STEP 2: FORWARD FFT
    // ==========================================
    fft_core(real, imag, 0); 

    // Debug: Cek Bin 0 (Harus 16000)
    *output_stream++ = 8888; // Marker Tengah
    *output_stream++ = real[0]; 

    // ==========================================
    // STEP 3: EQUALIZER PROCESSING (BYPASS)
    // ==========================================
    // Di sinilah nanti kita akan memanipulasi frekuensi.
    // Untuk sekarang, kita biarkan apa adanya (Flat EQ).

    // ==========================================
    // STEP 4: INVERSE FFT (IFFT)
    // ==========================================
    fft_core(real, imag, 1); 

    // ==========================================
    // STEP 5: OUTPUT FINAL
    // ==========================================
    *output_stream++ = 9999; // MARKER: RESULT
    
    // Output semua sample (Harus kembali jadi 1000)
    for (int i = 0; i < FFT_SIZE; i++) {
        *output_stream++ = real[i];
    }
    
    *output_stream++ = 7777; // END

    asm volatile ("ebreak");
    while(1);
    return 0;
}