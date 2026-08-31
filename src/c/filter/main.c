#include <stdint.h>
#include "filter.h"
#include "test_signal.h"

#define OUT_BASE   0x00020000u

/* ram_output is declared as mem[0:1023] in axi_ram.v -- 1024 words.  Packing
 * two 16-bit samples per word keeps a 256-sample run inside 128 words with
 * plenty of margin. */
#define OUT_WORDS  (SIG_LEN / 2)

static volatile uint32_t *const out_mem = (volatile uint32_t *)OUT_BASE;

/* Result header, so a memory dump is self-describing. */
#define HDR_MAGIC  0u   /* 0xF11700xx: xx = preset actually loaded */
#define HDR_LEN    1u
#define HDR_STATUS 2u
#define HDR_DATA   4u   /* packed samples start here */

static int16_t filtered[SIG_LEN];

int main(void)
{
    int i;
    uint32_t status = 0;

    /* 1. Is the peripheral on the bus?  This catches a wrong address range or
     *    a mis-wired interconnect before anything else confuses you. */
    if (!filt_present()) {
        out_mem[HDR_MAGIC]  = 0xDEAD0000u;
        out_mem[HDR_STATUS] = FILT_ID;      /* whatever we actually read */
        for (;;) { }
    }

    /* 2. Load the default Butterworth preset (500 Hz lowpass at fs = 8000). */
    filt_load(FILT_DEFAULT);

    /* 3. Verify one coefficient made it across the bus intact. */
    {
        volatile int32_t *s1 = FILT_S1_B0;
        if (s1[0] != (int32_t)filt_presets[FILT_DEFAULT].stage[0].b0)
            status |= 0x1u;
        if (s1[3] != (int32_t)filt_presets[FILT_DEFAULT].stage[0].a1)
            status |= 0x2u;
    }

    /* 4. Filter the block. */
    filt_block(test_signal, filtered, SIG_LEN);

    /* 5. Write the packed results out to ram_output, then the header.
     *    HDR_MAGIC is written LAST and acts as the completion flag: anything
     *    reading this memory (testbench, ILA, debugger) can poll word 0 and
     *    know the rest of the buffer is settled once it appears. */
    out_mem[HDR_LEN]    = (uint32_t)SIG_LEN;
    out_mem[HDR_STATUS] = status;

    for (i = 0; i < OUT_WORDS; i++) {
        uint32_t lo = (uint32_t)(uint16_t)filtered[2 * i];
        uint32_t hi = (uint32_t)(uint16_t)filtered[2 * i + 1];
        out_mem[HDR_DATA + i] = lo | (hi << 16);
    }

    out_mem[HDR_MAGIC]  = 0xF1170000u | (uint32_t)FILT_DEFAULT;

    /* 6. Done.  ebreak trips `trap`, which tb_picorv32_soc.v watches for to
     *    know when to dump ram_output -- same convention as eq_custom_instr. */
    asm volatile ("ebreak");
    for (;;) { }

    return 0;
}
