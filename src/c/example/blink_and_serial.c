#include <stdint.h>

// UARTLite Register Map (Xilinx)
#define UART_BASE    0x00020000
#define UART_RX      (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_TX      (*(volatile uint32_t*)(UART_BASE + 0x04))
#define UART_STATUS  (*(volatile uint32_t*)(UART_BASE + 0x08))
#define UART_CTRL    (*(volatile uint32_t*)(UART_BASE + 0x0C))

#define GPIO_ADDRESS 			((volatile uint32_t*)0x00030000)

// Status register bits
#define TX_FIFO_FULL  (1 << 3)
#define TX_FIFO_EMPTY (1 << 2)
#define RX_FIFO_VALID (1 << 0)

void delay(void) {
    for(volatile uint32_t i = 0; i < 500000; i++) asm("nop");
}

void uart_init(void) {
    UART_CTRL = 0x03;  // reset TX and RX FIFO
    UART_CTRL = 0x00;  // clear reset
}

void uart_putc(char c) {
    while (UART_STATUS & TX_FIFO_FULL);  // wait until not full
    UART_TX = (uint32_t)c;
}

void uart_puts(const char* s) {
    while (*s) uart_putc(*s++);
}

int main() {
    uart_init();  // reset FIFO first!
    
    while(1) {
        uart_puts("CPU0 OK\r\n");
        delay();
		*GPIO_ADDRESS = 0x000f;
		delay();
		*GPIO_ADDRESS = 0x0;
		delay();
    }
    return 0;
}