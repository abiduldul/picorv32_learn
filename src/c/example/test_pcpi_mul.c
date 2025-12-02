#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main() {
	volatile int a = 123;
    volatile int b = 456;
    volatile int result = 0;

    // Lakukan perkalian berulang-ulang
    for (int i = 0; i < 100; i++) {
        result += a * b;
    }
    
    // Sinyal untuk testbench bahwa program selesai
    // (Cara ini bergantung pada testbench Anda)
    asm volatile ("csrwi 0x780, 1"); // Contoh sinyal 'halt'
}