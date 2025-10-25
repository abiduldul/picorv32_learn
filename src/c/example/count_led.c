#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define GPIO_ADDRESS 			((volatile uint32_t*)0x00020000)

int main() {
	uint32_t count = 0;

	while(1) {
		*GPIO_ADDRESS = count++ & 0xffff;
		for(uint32_t i = 0; i < 150000; i++) asm("nop");
	}
	
	return 0;
}