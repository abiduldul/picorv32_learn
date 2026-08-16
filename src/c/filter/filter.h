/*
 * filter.h -- driver for the AXI4-Lite Butterworth peripheral.
 *
 * The peripheral has no sample-rate hardware.  Writing FILT_DATA_IN is what
 * advances the delay line, so the sample rate is whatever rate this code
 * writes at.  FILT_FS in filter_coeff.h is the rate the coefficients were
 * designed for -- generate your input signal at that same rate or the cutoff
 * frequency will not be what you asked for.
 */
#ifndef FILTER_H
#define FILTER_H

#include <stdint.h>
#include "filter_coeff.h"

#define FILT_BASE       0x00030000u

#define FILT_CTRL       (*(volatile uint32_t *)(FILT_BASE + 0x00))
#define FILT_STATUS     (*(volatile uint32_t *)(FILT_BASE + 0x04))
#define FILT_DATA_IN    (*(volatile int32_t  *)(FILT_BASE + 0x08))
#define FILT_DATA_OUT   (*(volatile int32_t  *)(FILT_BASE + 0x0C))
#define FILT_S1_B0      (  (volatile int32_t *)(FILT_BASE + 0x10))
#define FILT_S2_B0      (  (volatile int32_t *)(FILT_BASE + 0x24))
#define FILT_ID         (*(volatile uint32_t *)(FILT_BASE + 0x38))

#define FILT_ID_VALUE   0xF1170001u

#define FILT_CTRL_CLEAR 0x1u

/* Samples of pure delay through the cascade: one per section, plus one for
 * the register between them.  out[n] corresponds to in[n - FILT_LATENCY]. */
#define FILT_LATENCY    (FILT_N_STAGE + 1)

/* Is the peripheral actually responding on the bus? */
static inline int filt_present(void)
{
    return FILT_ID == FILT_ID_VALUE;
}

/* Zero the delay line.  Always do this after changing coefficients --
 * otherwise stale state runs through the new transfer function and can
 * produce a large transient. */
static inline void filt_clear(void)
{
    FILT_CTRL = FILT_CTRL_CLEAR;
}

/* Load one of the generated Butterworth presets. */
static void filt_load(int preset)
{
    const filt_preset_t *p = &filt_presets[preset];
    volatile int32_t *s1 = FILT_S1_B0;
    volatile int32_t *s2 = FILT_S2_B0;

    s1[0] = p->stage[0].b0;  s1[1] = p->stage[0].b1;  s1[2] = p->stage[0].b2;
    s1[3] = p->stage[0].a1;  s1[4] = p->stage[0].a2;

    s2[0] = p->stage[1].b0;  s2[1] = p->stage[1].b1;  s2[2] = p->stage[1].b2;
    s2[3] = p->stage[1].a1;  s2[4] = p->stage[1].a2;

    filt_clear();
}

/* Push one sample, read one back.  The value returned lags the value pushed
 * by FILT_LATENCY samples. */
static inline int32_t filt_step(int32_t x)
{
    FILT_DATA_IN = x;
    return FILT_DATA_OUT;
}

/* Filter a block.  dst[] is aligned so that dst[n] corresponds to src[n]:
 * the first FILT_LATENCY outputs are the pipeline fill and are discarded,
 * and the tail is flushed with zeros. */
static void filt_block(const int16_t *src, int16_t *dst, int n)
{
    int i;

    for (i = 0; i < FILT_LATENCY; i++)
        (void)filt_step(src[i]);

    for (i = 0; i < n - FILT_LATENCY; i++)
        dst[i] = (int16_t)filt_step(src[i + FILT_LATENCY]);

    for (; i < n; i++)
        dst[i] = (int16_t)filt_step(0);
}

#endif /* FILTER_H */
