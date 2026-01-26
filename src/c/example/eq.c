#include <stdint.h>
#include "audio_data.h" // Input tetap int16_t

#define FFT_SIZE 128
#define FIXED_SHIFT 10    // Q10 Format
#define MAGIC_ADDR 0x00020000
#define MAX_OUTPUT_COUNT 4096 

// Tabel Sin/Cos tetap int16_t karena nilainya max 1024
const int16_t SinTable[128] = {
    0, 50, 100, 150, 200, 249, 297, 345, 392, 437, 482, 525, 567, 608, 647, 684, 
    720, 754, 786, 817, 846, 872, 897, 920, 940, 959, 976, 990, 1002, 1012, 1019, 1023, 
    1024, 1023, 1019, 1012, 1002, 990, 976, 959, 940, 920, 897, 872, 846, 817, 786, 
    754, 720, 684, 647, 608, 567, 525, 482, 437, 392, 345, 297, 249, 200, 150, 100, 
    50, 0, -50, -100, -150, -200, -249, -297, -345, -392, -437, -482, -525, -567, -608, 
    -647, -684, -720, -754, -786, -817, -846, -872, -897, -920, -940, -959, -976, -990, -1002, 
    -1012, -1019, -1023, -1024, -1023, -1019, -1012, -1002, -990, -976, -959, -940, -920, -897, -872, 
    -846, -817, -786, -754, -720, -684, -647, -608, -567, -525, -482, -437, -392, -345, -297, 
    -249, -200, -150, -100, -50
};

const int16_t CosTable[128] = {
    1024, 1023, 1019, 1012, 1002, 990, 976, 959, 940, 920, 897, 872, 846, 817, 786, 754, 
    720, 684, 647, 608, 567, 525, 482, 437, 392, 345, 297, 249, 200, 150, 100, 50, 
    0, -50, -100, -150, -200, -249, -297, -345, -392, -437, -482, -525, -567, -608, -647, 
    -684, -720, -754, -786, -817, -846, -872, -897, -920, -940, -959, -976, -990, -1002, -1012, 
    -1019, -1023, -1024, -1023, -1019, -1012, -1002, -990, -976, -959, -940, -920, -897, -872, -846, 
    -817, -786, -754, -720, -684, -647, -608, -567, -525, -482, -437, -392, -345, -297, -249, 
    -200, -150, -100, -50, 0, 50, 100, 150, 200, 249, 297, 345, 392, 437, 482, 
    525, 567, 608, 647, 684, 720, 754, 786, 817, 846, 872, 897, 920, 940, 959, 976, 
    990, 1002, 1012, 1019, 1023
};

// PERBAIKAN: Gunakan int32_t untuk buffer data agar tidak overflow saat perhitungan
void fixed_fft(int32_t *real, int32_t *imag, int n, int inverse) {
    int i, j, k, l, m, step;
    int32_t tr, ti; // PERBAIKAN: Temp variables jadi 32-bit
    int16_t c, s;   // Sin/Cos tetap 16-bit

    // Bit-reversal
    j = 0;
    for (i = 0; i < n - 1; i++) {
        if (i < j) {
            tr = real[i]; real[i] = real[j]; real[j] = tr;
            tr = imag[i]; imag[i] = imag[j]; imag[j] = tr;
        }
        k = n >> 1;
        while (k <= j) { j -= k; k >>= 1; }
        j += k;
    }
    
    // Butterfly
    for (l = 1, m = 1; l < n; l <<= 1, m++) {
        step = n >> m;
        for (j = 0; j < l; j++) {
            c = CosTable[j * step];
            s = inverse ? -SinTable[j * step] : SinTable[j * step];
            for (i = j; i < n; i += (l << 1)) {
                // PERBAIKAN: Casting ke int32_t saat perkalian tidak lagi diperlukan karena buffer sudah int32_t,
                // tapi shift tetap dilakukan. 
                // Logika: (32bit * 16bit) >> 10 = 32bit (Aman)
                tr = (real[i + l] * c - imag[i + l] * s) >> FIXED_SHIFT;
                ti = (real[i + l] * s + imag[i + l] * c) >> FIXED_SHIFT;
                
                real[i + l] = real[i] - tr;
                imag[i + l] = imag[i] - ti;
                real[i] += tr;
                imag[i] += ti;
            }
        }
    }
}

int main() {
    // PERBAIKAN: Gunakan int32_t untuk menampung lonjakan nilai FFT
    int32_t real[FFT_SIZE];
    int32_t imag[FFT_SIZE];

    // Gain dalam Q10 (2048 = 2.0)
    int32_t bass_gain   = 2048; 
    int32_t mid_gain    = 1024; 
    int32_t treble_gain = 512;  

    volatile int32_t *output_stream = (volatile int32_t*) MAGIC_ADDR;
    int output_counter = 0;

    for (int b = 0; b < AUDIO_SAMPLE_COUNT - FFT_SIZE; b += FFT_SIZE) {
        
        // 1. Load Data
        for (int i = 0; i < FFT_SIZE; i++) {
            real[i] = (int32_t)audio_raw_data[b + i]; // Cast input 16-bit ke 32-bit
            imag[i] = 0;
        }

        // 2. Forward FFT
        fixed_fft(real, imag, FFT_SIZE, 0);

        // 3. Apply Equalizer Gains
        for (int i = 0; i <= FFT_SIZE / 2; i++) {
            int32_t gain;

            if (i < 8)       gain = bass_gain;   
            else if (i < 24) gain = mid_gain;    
            else             gain = treble_gain; 

            // PERBAIKAN: Sekarang aman dari overflow karena real[] adalah int32_t
            // (int32 * int32) >> 10 -> Aman selama hasil perkalian < 2 Miliar
            real[i] = (real[i] * gain) >> FIXED_SHIFT;
            imag[i] = (imag[i] * gain) >> FIXED_SHIFT;

            if (i > 0 && i < FFT_SIZE / 2) {
                int mirror_idx = FFT_SIZE - i;
                real[mirror_idx] = (real[mirror_idx] * gain) >> FIXED_SHIFT;
                imag[mirror_idx] = (imag[mirror_idx] * gain) >> FIXED_SHIFT;
            }
        }

        // 4. Inverse FFT
        fixed_fft(real, imag, FFT_SIZE, 1);

        // 5. Write to Output
        for (int i = 0; i < FFT_SIZE; i++) {
            if (output_counter < MAX_OUTPUT_COUNT) {
                // Scale back: FFT Size scaling (div 128)
                int32_t final_val = real[i] >> 7; 
                
                // Opsional: Clipping agar muat di int16 (jika perlu simulasi DAC 16-bit)
                // Tapi untuk testbench RAM, kita kirim raw value saja.
                
                *output_stream++ = final_val;
                output_counter++;
            }
        }
    }

    asm volatile ("ebreak");
    while(1);
    return 0;
}