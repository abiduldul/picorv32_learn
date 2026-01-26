#ifndef TABLES_H
#define TABLES_H

#include <stdint.h>

#define FFT_SIZE 64
#define FIXED_SHIFT 10
#define LOG2_N 6  // Untuk scaling IFFT (div by N)

// Tabel Sin/Cos untuk N=64
// Sudut 0 sampai Pi (N/2 sample)
const int16_t SinTable[32] = {
    0, 100, 199, 297, 391, 482, 568, 649, 724, 791, 851, 903, 946, 979, 1004, 1019, 1024, 1019, 1004, 979, 946, 903, 851, 791, 724, 649, 568, 482, 391, 297, 199, 100
};

const int16_t CosTable[32] = {
    1024, 1019, 1004, 979, 946, 903, 851, 791, 724, 649, 568, 482, 391, 297, 199, 100, 0, -100, -199, -297, -391, -482, -568, -649, -724, -791, -851, -903, -946, -979, -1004, -1019
};

#endif
