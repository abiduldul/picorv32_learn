#include <stdint.h>
#include "tables.h"
#include "audio_data.h"

#define MAGIC_ADDR 0x00020000

// HARDWARE MACROS
// No output — rs1=real_val, rs2=imag_val
#define hw_bload(real_val, imag_val) \
    __asm__ volatile ("bload %0, %1" \
        : \
        : "r"((int32_t)(real_val)), "r"((int32_t)(imag_val)) \
        : "memory")

// rd=tr_out(output), rs1=c_val, rs2=s_val
#define hw_bfly(tr_out, c_val, s_val) \
    __asm__ volatile ("bfly %0, %1, %2" \
        : "=r"(tr_out) \
        : "r"((int32_t)(c_val)), "r"((int32_t)(s_val)) \
        : "memory")

// rd=ti_out(output), no inputs
#define hw_bget(ti_out) \
    __asm__ volatile ("bget %0" \
        : "=r"(ti_out) \
        : \
        : "memory")

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
                    // tr = (real[pair] * c - imag[pair] * s) >> FIXED_SHIFT;
                    // ti = (real[pair] * s + imag[pair] * c) >> FIXED_SHIFT;
                    
                    // bload feeds real[pair] and imag[pair] to coprocessor
                    hw_bload(real[pair], imag[pair]);
                    hw_bfly(tr, c, s);
                    hw_bget(ti);
                } else {
                    // tr = (real[pair] * c + imag[pair] * s) >> FIXED_SHIFT;
                    // ti = (imag[pair] * c - real[pair] * s) >> FIXED_SHIFT;
                    
                    // bfly with -s computes:
                    hw_bload(real[pair], imag[pair]);
                    hw_bfly(tr, c, -s);
                    hw_bget(ti);
                }
                // Writeback results
                real[pair] = real[i] - tr;
                imag[pair] = imag[i] - ti;
                real[i]   += tr;
                imag[i]   += ti;
            }
        }
    }

    // 3. Scaling (IFFT only)
    if (inverse) {
        for (i = 0; i < FFT_SIZE; i++) {
            real[i] = real[i] >> LOG2_N;
            imag[i] = imag[i] >> LOG2_N;
        }
    }
}

// --- 3-BAND EQ ---
void process_math_only(int32_t *chunk_real, int32_t *chunk_imag) {

    // 1. FFT
    fft_core(chunk_real, chunk_imag, 0);

    // 2. Equalizer
    int32_t gain;
    for (int i = 0; i < FFT_SIZE; i++) {
        int idx_checked = (i > FFT_SIZE/2) ? (FFT_SIZE - i) : i;
        if      (idx_checked <= 4)  gain = 2048; // BASS  2.0x
        else if (idx_checked <= 16) gain = 512;  // MID   0.5x
        else                        gain = 256;  // TREBLE 0.25x

        chunk_real[i] = (chunk_real[i] * gain) >> FIXED_SHIFT;
        chunk_imag[i] = (chunk_imag[i] * gain) >> FIXED_SHIFT;
    }

    // 3. IFFT
    fft_core(chunk_real, chunk_imag, 1);
}

int main() {
    volatile int32_t *output_stream = (volatile int32_t*) MAGIC_ADDR;

    int32_t buffer_real[FFT_SIZE];
    int32_t buffer_imag[FFT_SIZE];
    int buffer_index = 0;

    for (int i = 0; i < AUDIO_LEN; i++) {
        buffer_real[buffer_index] = audio_data[i];
        buffer_imag[buffer_index] = 0;
        buffer_index++;

        if (buffer_index == FFT_SIZE) {
            process_math_only(buffer_real, buffer_imag);

            for (int k = 0; k < FFT_SIZE; k++) {
                *output_stream++ = buffer_real[k];
            }

            buffer_index = 0;
        }
    }

    asm volatile ("ebreak");
    while(1);
    return 0;
}