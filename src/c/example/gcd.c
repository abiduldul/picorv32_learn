#include <stdint.h>

// 1. Hardware Wrapper (The Bridge)
// Uses Custom-1 Opcode (0x2B)
uint32_t hardware_gcd(uint32_t a, uint32_t b) {
    uint32_t result;
    asm volatile (
        ".insn r 0x2B, 0, 0, %0, %1, %2"
        : "=r"(result)
        : "r"(a), "r"(b)
    );
    return result;
}

// 2. Software Reference (For Checking)
uint32_t software_gcd(uint32_t a, uint32_t b) {
    while (b != 0) {
        uint32_t temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}

// uint32_t software_gcd(uint32_t a, uint32_t b) {
//     // Handle the zero case (just like hardware check)
//     if (a == 0) {
//         return b;
//     } else {
//         if (a > b) {
//             a = a - b;
//         } else {
//             b = b - a;
//         }
//     }
//     return a;
// }

int main() {
    volatile uint32_t num1 = 14;
    volatile uint32_t num2 = 0;
    
    // Expected GCD: 14
    uint32_t hw_result = hardware_gcd(num1, num2);
    // uint32_t sw_result = software_gcd(num1, num2);
    asm volatile ("csrwi 0x780, 2");
    
    // if (hw_result == sw_result) {
    //     // SUCCESS (Write 1 to CSR 0x780)
    //     asm volatile ("csrwi 0x780, 1");
    // } else {
    //     // FAIL (Write 0 to CSR 0x780)
    //     asm volatile ("csrwi 0x780, 0");
    // }

    return 0;
}