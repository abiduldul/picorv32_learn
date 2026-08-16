#include <stdint.h>

extern uint32_t _sdata;
extern uint32_t _edata;

extern uint32_t _etext;

extern uint32_t _sbss;
extern uint32_t _sbss_end;
extern uint32_t _ebss;

extern uint32_t _la_data;

void ram_init() {
/*	uint32_t size = &_edata - &_sdata;
	uint8_t* pSrc = (uint8_t*)&_etext;
	uint8_t* pDst = (uint8_t*)&_sdata;
	
	while(size--) {
		*(pDst++) = *(pSrc++);
	}
	
	size = &_ebss - &_sbss;
	pDst = (uint8_t*)&_sbss;
	
	while(size--) {
		*(pDst++) = 0;
	}*/

	// Copy initialized data from flash (_etext) to RAM (_sdata to _edata)
    uint8_t *src = (uint8_t*)&_la_data;
    uint8_t *dst = (uint8_t*)&_sdata;

    while (dst < (uint8_t*)&_edata) {
        *dst++ = *src++;
    }

    // Zero initialize the .bss section
    dst = (uint8_t*)&_sbss;
    while (dst < (uint8_t*)&_sbss_end) {
        *dst++ = 0;
    }
	
	return;
}