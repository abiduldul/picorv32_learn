#include <stdint.h>

// 1. Software implementation (The "Control" group)
// We use this to verify that the hardware is telling the truth.
uint32_t software_bitrev(uint32_t n) {
    uint32_t reverse = 0;
    for (int i = 0; i < 32; i++) {
        if ((n >> i) & 1) {
            reverse |= (1 << (31 - i));
        }
    }
    return reverse;
}

// 2. Hardware implementation (The "Test" group)
// This functions wraps your custom assembly instruction.
uint32_t hardware_bitrev(uint32_t input) {
    uint32_t result;
    
    // --- MAPPING TO VERILOG ---
    // Your Verilog checks for:
    // Opcode: 7'b0001011 -> 0x0B  
    // Funct3: 3'b001     -> 1     
    // Funct7: 7'b0000001 -> 1     
    //
    // Syntax: .insn r opcode, func3, func7, rd, rs1, rs2
    asm volatile (
        ".insn r 0x0B, 1, 1, %0, %1, x0"
        : "=r"(result)   // Output (%0) -> mapped to pcpi_rd
        : "r"(input)     // Input  (%1) -> mapped to pcpi_rs1
    );
    
    return result; // This value comes from your hardware module!
}

int main() {
    volatile uint32_t test_val = 0x12345678; // Complex bit pattern
    volatile uint32_t expected = 0;
    volatile uint32_t actual = 0;

    // Calculate using C
    expected = software_bitrev(test_val);

    // Calculate using YOUR Custom Hardware
    actual = hardware_bitrev(test_val);

    // Check result
    if (actual == expected) {
        // SUCCESS!
        // If you are simulating, look for this infinite loop.
        // actual and expected match.
        asm volatile ("csrwi 0x780, 1");
        // while(1); 
    } else {
        // FAIL
        // The hardware calculation was wrong.
        asm volatile ("csrwi 0x780, 0");
        // while(1);
    }

    return 0;
}