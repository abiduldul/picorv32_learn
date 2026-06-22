// PROGRAM GABUNGAN (Program 1 + Program 2), Nexys A7
// =================================================================
// sw[15] : OFF -> Program 1 (variasi blink + counter 7-seg)
//          ON  -> Program 2 (15-bit switch biner -> LED + desimal 7-seg)
//
// --- Program 1 (sw[15] OFF) ---
//   sw[0] : ON=simple blink            | OFF=ping-pong
//   sw[1] : ON=animasi simetris (sw[0] pilih arah) | OFF=mode sw[0]
//   sw[2] : ON=semua digit 0-9 bareng  | OFF=counter desimal 0-9999
//   sw[3] : ON=7-seg menyala           | OFF=7-seg semua 0  (master enable)
//
// --- Program 2 (sw[15] ON) ---
//   LED   = nilai 15-bit switch (sw[0..14]); LED[15] mati
//   7-seg = nilai switch tsb sebagai DESIMAL (0..32767)
#include <stdint.h>

#define GPIO_LED ((volatile uint32_t*)0x00020000)  // tulis=LED, baca=switch
#define GPIO_SEG ((volatile uint32_t*)0x00020004)  // tulis=nilai 7-seg

#define TICK_DELAY    15000u   // delay dasar per tick (percepat/perlambat semua)
#define DIV_BLINK     100u     // simple blink
#define DIV_PINGPONG  5u      // ping-pong  (2x lebih cepat dari rev2=50)
#define DIV_SYMMETRIC 5u      // tengah/samping (2x lebih cepat dari rev2=50)
#define SEG_ALLDIV    40u      // counter 0-9 semua digit: SETENGAH kecepatan (rev2=20)
                               //   ^-- ubah angka ini kalau maksud "0.5 kali" berbeda

static void delay(uint32_t n){ for(volatile uint32_t i=0;i<n;i++) asm volatile("nop"); }

// biner -> packed BCD (1 digit desimal per nibble) untuk tampilan DESIMAL
static uint32_t to_bcd(uint32_t n){
    uint32_t bcd = 0; int s = 0;
    while(n && s < 32){ bcd |= (n % 10) << s; n /= 10; s += 4; }
    return bcd;
}

static uint16_t led_pattern(uint32_t sw, uint32_t tick){
    uint32_t sw0 = sw & 1, sw1 = (sw >> 1) & 1;
 
    if(!sw1){
        if(sw0){                                           // simple blink
            uint32_t f = tick / DIV_BLINK;
            return (f & 1) ? 0xFFFF : 0x0000;
        } else {                                           // ping-pong 16 LED penuh
            uint32_t f = tick / DIV_PINGPONG;
            uint32_t p = f % 30, pos = (p < 16) ? p : 30 - p;
            return (uint16_t)(1u << pos);
        }
    } else {
        // ping-pong 2 paruh: titik memantul 0..7..1 dalam tiap paruh 8 LED
        uint32_t f = tick / DIV_SYMMETRIC;
        uint32_t q = f % 14;
        uint32_t local = (q < 8) ? q : 14 - q;             // 0..7..1
        uint16_t right = (uint16_t)(1u << local);          // titik di LED[0..7]
        if(sw0)
            // berlawanan: paruh kiri dicerminkan -> bertemu di tengah lalu berpisah
            return (uint16_t)(right | (1u << (15 - local)));
        else
            // bersamaan: paruh kiri searah -> dua titik sejajar
            return (uint16_t)(right | (1u << (8 + local)));
    }
}

int main(void){
    uint32_t tick = 0;
    while(1){
        uint32_t sw = *GPIO_LED & 0xFFFF;   // baca 16 switch

        if(sw & 0x8000){
            /* ===== PROGRAM 2 (sw[15] ON) : 15-bit ===== */
            uint32_t val = sw & 0x7FFF;     // 15 bit (sw0..sw14)
            *GPIO_LED = val;                // LED ikut switch (LED15 mati)
            *GPIO_SEG = to_bcd(val);        // desimal di 7-seg
        } else {
            /* ===== PROGRAM 1 (sw[15] OFF) ===== */
            uint32_t sw2 = (sw >> 2) & 1;   // mode 7-seg
            uint32_t sw3 = (sw >> 3) & 1;   // enable 7-seg

            if(!sw3)      *GPIO_SEG = 0;                                      // mati -> semua 0
            else if(sw2)  *GPIO_SEG = ((tick / SEG_ALLDIV) % 10) * 0x11111111u; // 0-9 semua digit (lambat)
            else          *GPIO_SEG = to_bcd(tick % 10000);                  // 0-9999 desimal (tetap)

            *GPIO_LED = led_pattern(sw, tick);
        }

        delay(TICK_DELAY);
        tick++;
    }
}