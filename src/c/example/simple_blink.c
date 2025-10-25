#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define GPIO_ADDRESS 			((volatile uint32_t*)0x00020000)

int main() {
	while(1) {
		*GPIO_ADDRESS = 0xffff;
		for(uint32_t i = 0; i < 500000; i++) asm("nop");
        *GPIO_ADDRESS = 0x0;
		for(uint32_t i = 0; i < 500000; i++) asm("nop");
	}
	
	return 0;
}