#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define GPIO_ADDRESS1 			((volatile uint32_t*)0x00020000)
#define GPIO_ADDRESS2 			((volatile uint32_t*)0x00030000)

int main() {
	while(1) {
		for(uint32_t i = 0; i < 5; i++){
			*GPIO_ADDRESS1 = 0x000f;
			for(uint32_t i = 0; i < 500000; i++) asm("nop");
			*GPIO_ADDRESS1 = 0x0;
			for(uint32_t i = 0; i < 500000; i++) asm("nop");
		}
        
		for(uint32_t i = 0; i < 10; i++){
			*GPIO_ADDRESS2 = 0xf000;
			for(uint32_t i = 0; i < 500000; i++) asm("nop");
			*GPIO_ADDRESS2 = 0x0;
			for(uint32_t i = 0; i < 500000; i++) asm("nop");
		}
	}
	
	return 0;
}