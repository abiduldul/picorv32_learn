// PROGRAM 1 (rev2) - Variasi blink LED + counter 7-segment, dikontrol switch.
//   sw[0] : ON = simple blink (semua LED)   | OFF = ping-pong (1 LED memantul)
//   sw[1] : ON = animasi simetris (sw[0] pilih arah: tengah->samping / samping->tengah)
//           OFF = aktifkan mode sw[0]
//   sw[2] : ON = semua digit 7-seg menghitung 0-9 bersamaan
//           OFF = counter desimal cepat 0-9999
//
// rev2: kecepatan per-mode disetel (blink 2x, ping-pong & simetris 4x lebih cepat).
#include <stdint.h>

#define GPIO_LED ((volatile uint32_t*)0x00020000)  // tulis = LED, baca = switch
#define GPIO_SEG ((volatile uint32_t*)0x00020004)  // tulis = nilai 7-seg (8 nibble)

#define TICK_DELAY    15000u   // delay dasar per tick
#define DIV_BLINK     100u     // blink: 2x lebih cepat (dulu 200)
#define DIV_PINGPONG  50u      // ping-pong: 4x lebih cepat (dulu 200)
#define DIV_SYMMETRIC 50u      // tengah/samping: 4x lebih cepat (dulu 200)
#define SEG_ALLDIV    20u      // kecepatan counter "semua digit"

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
        if(sw0){                                       // simple blink
            uint32_t f = tick / DIV_BLINK;
            return (f & 1) ? 0xFFFF : 0x0000;
        } else {                                       // ping-pong
            uint32_t f = tick / DIV_PINGPONG;
            uint32_t p = f % 30, pos = (p < 16) ? p : 30 - p;
            return 1u << pos;
        }
    } else {
        uint32_t f = tick / DIV_SYMMETRIC;
        uint32_t k = f % 8;
        if(sw0) return (1u << (7 - k)) | (1u << (8 + k));   // tengah -> samping
        else    return (1u << k)       | (1u << (15 - k));  // samping -> tengah
    }
}

int main(void){
    uint32_t tick = 0;
    while(1){
        uint32_t sw  = *GPIO_LED & 0xFFFF;   // baca 16 switch
        uint32_t sw2 = (sw >> 2) & 1;

        if(sw2) *GPIO_SEG = ((tick / SEG_ALLDIV) % 10) * 0x11111111u; // 0-9 semua digit
        else    *GPIO_SEG = to_bcd(tick % 10000);                     // desimal 0-9999

        *GPIO_LED = led_pattern(sw, tick);

        delay(TICK_DELAY);
        tick++;
    }
}