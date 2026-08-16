#!/usr/bin/env python3
"""
Butterworth coefficient generator for the AXI-Lite filter peripheral.

Emits:
  filter_coeff.h      C header with the coefficient bank (loaded at runtime)
  filter_coeff_ref.txt  human-readable table + gain check
  golden/*.txt        reference impulse responses for the RTL testbench

Run:  python3 gen_filter_coeff.py
"""
import os
import numpy as np
from scipy import signal

FS = 8000
Q = 14
SCALE = 1 << Q
N_STAGE = 2          # hardware has exactly two cascaded biquads
IMPULSE_LEN = 64     # length of the golden reference vectors
LATENCY = N_STAGE + 1  # samples of pure delay through the cascade

PRESETS = [
    {"id": 0, "name": "LP_500",      "type": "low",      "fc": 500,         "order": 4},
    {"id": 1, "name": "LP_800",      "type": "low",      "fc": 800,         "order": 4},
    {"id": 2, "name": "LP_1000",     "type": "low",      "fc": 1000,        "order": 4},
    {"id": 3, "name": "HP_500",      "type": "high",     "fc": 500,         "order": 4},
    {"id": 4, "name": "HP_800",      "type": "high",     "fc": 800,         "order": 4},
    {"id": 5, "name": "HP_1000",     "type": "high",     "fc": 1000,        "order": 4},
    {"id": 6, "name": "BP_500_1000", "type": "bandpass", "fc": [500, 1000], "order": 2},
    {"id": 7, "name": "BS_500_1000", "type": "bandstop", "fc": [500, 1000], "order": 2},
]

DEFAULT = 0          # preset loaded by the C program at boot


def q14(x):
    """Round a float to Q2.14, clipping into signed 16-bit range."""
    q = int(np.round(x * SCALE))
    if q > 32767:
        print(f"  [WARN] coefficient clipped: {x:.6f} -> +32767")
        q = 32767
    elif q < -32768:
        print(f"  [WARN] coefficient clipped: {x:.6f} -> -32768")
        q = -32768
    return q


def rebalance(sos):
    """
    scipy hands back sections where the first one has tiny gain and the second
    has huge gain (0.022 and 45.7 for the 500 Hz lowpass).  In fixed point that
    crushes the signal between the sections, then amplifies the quantization
    noise back up.  Move gain from the later section into the earlier one by a
    power of two -- the overall transfer function is unchanged, but stage 1 now
    uses far more of the available range.
    """
    if len(sos) < 2:
        return sos, 0
    sos = np.array(sos, dtype=float)

    # worst-case (L1) output of section 0 for a full-scale input
    b = sos[0][:3]
    a = np.concatenate(([1.0], sos[0][4:6]))
    _, h = signal.dimpulse((b, a, 1.0 / FS), n=512)
    l1 = np.abs(h[0]).sum()
    peak = 32767.0 * l1

    HEADROOM = 1 << 17          # keep stage 1 inside half the 19-bit range
    COEFF_MAX = 32767.0 / SCALE  # Q2.14 cannot represent 2.0 or beyond
    b0_max = np.abs(sos[0][:3]).max()
    b1_min = np.abs(sos[1][:3][sos[1][:3] != 0]).min() if np.any(sos[1][:3]) else 1.0

    k = 0
    while k < 8:
        n = k + 1
        if peak * (1 << n) > HEADROOM:          # stage 1 would overflow
            break
        if b0_max * (1 << n) >= COEFF_MAX:      # stage 1 coefficient out of range
            break
        if b1_min / (1 << n) < 4.0 / SCALE:     # stage 2 coefficient underflows
            break
        k = n

    if k:
        sos[0][:3] *= (1 << k)
        sos[1][:3] /= (1 << k)
    return sos, k


def design(p):
    """Return a list of N_STAGE (b0,b1,b2,a1,a2) integer tuples, Q2.14."""
    sos = signal.butter(p["order"], p["fc"], btype=p["type"], fs=FS, output="sos")
    sos, shift = rebalance(sos)
    stages = []
    for b0, b1, b2, a0, a1, a2 in sos:
        stages.append((q14(b0), q14(b1), q14(b2), q14(a1), q14(a2)))
    # pad unused sections with a pass-through H(z) = 1
    while len(stages) < N_STAGE:
        stages.append((SCALE, 0, 0, 0, 0))
    if len(stages) > N_STAGE:
        raise ValueError(f"{p['name']}: needs {len(stages)} sections, hardware has {N_STAGE}")
    return stages, shift


def dc_gain(stages):
    g = 1.0
    for b0, b1, b2, a1, a2 in stages:
        num = b0 + b1 + b2
        den = SCALE + a1 + a2
        g *= num / den
    return g


SAT19 = (1 << 18) - 1


def cascade_hw(x, stages):
    """
    Bit-exact model of the RTL: both biquads see the same `valid` pulse, so
    stage 2 consumes stage 1's PREVIOUS output, not the one produced on the
    same edge.  Rounds to nearest and saturates the 19-bit state, matching
    filter_biquad.v exactly.
    """
    st = [dict(xc=0, x1=0, x2=0, y1=0, y2=0) for _ in stages]
    out = []
    for xin in x:
        ins = [xin] + [st[i]["y1"] for i in range(len(stages) - 1)]
        nxt = []
        for i, coeffs in enumerate(stages):
            b0, b1, b2, a1, a2 = coeffs
            s_ = st[i]
            acc = (s_["xc"] * b0 + s_["x1"] * b1 + s_["x2"] * b2
                   - s_["y1"] * a1 - s_["y2"] * a2)
            y = (acc + (1 << (Q - 1))) >> Q
            nxt.append(max(-SAT19, min(SAT19, y)))
        for i in range(len(stages)):
            s_ = st[i]
            s_["x2"], s_["x1"], s_["xc"] = s_["x1"], s_["xc"], ins[i]
            s_["y2"], s_["y1"] = s_["y1"], nxt[i]
        out.append(max(-32767, min(32767, st[-1]["y1"])))
    return out


def float_ref(x, stages):
    """Same filter in floating point via scipy, for an independent check."""
    sos = np.array([[b0 / SCALE, b1 / SCALE, b2 / SCALE,
                     1.0, a1 / SCALE, a2 / SCALE]
                    for (b0, b1, b2, a1, a2) in stages])
    return signal.sosfilt(sos, np.array(x, dtype=float))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    golden_dir = os.path.join(here, "golden")
    os.makedirs(golden_dir, exist_ok=True)

    designs = []
    print(f"Designing Butterworth presets at fs = {FS} Hz, Q2.{Q}\n")
    for p in PRESETS:
        stages, shift = design(p)
        g = dc_gain(stages)
        designs.append((p, stages, g))
        print(f"  {p['name']:<12} DC gain = {g:8.4f}   "
              f"stage-1 gain moved up by 2^{shift}")

    # ---- C header -------------------------------------------------------
    h = []
    h.append("/* Auto-generated by gen_filter_coeff.py -- do not edit by hand. */")
    h.append("#ifndef FILTER_COEFF_H")
    h.append("#define FILTER_COEFF_H")
    h.append("")
    h.append("#include <stdint.h>")
    h.append("")
    h.append(f"#define FILT_FS        {FS}")
    h.append(f"#define FILT_Q_SHIFT   {Q}")
    h.append(f"#define FILT_ONE       {SCALE}   /* 1.0 in Q2.{Q} */")
    h.append(f"#define FILT_N_STAGE   {N_STAGE}")
    h.append(f"#define FILT_N_PRESET  {len(PRESETS)}")
    h.append(f"#define FILT_DEFAULT   {DEFAULT}   /* {PRESETS[DEFAULT]['name']} */")
    h.append("")
    h.append("/* One second-order section: y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2 */")
    h.append("typedef struct { int16_t b0, b1, b2, a1, a2; } filt_sos_t;")
    h.append("")
    h.append("typedef struct {")
    h.append("    const char *name;")
    h.append("    filt_sos_t  stage[FILT_N_STAGE];")
    h.append("} filt_preset_t;")
    h.append("")
    for p, stages, _ in designs:
        h.append(f"#define FILT_{p['name']:<12} {p['id']}")
    h.append("")
    h.append("static const filt_preset_t filt_presets[FILT_N_PRESET] = {")
    for p, stages, g in designs:
        fc = p["fc"] if isinstance(p["fc"], int) else f"{p['fc'][0]}-{p['fc'][1]}"
        h.append(f"    /* [{p['id']}] {p['name']}  fc = {fc} Hz, "
                 f"order {p['order']}, DC gain {g:.4f} */")
        h.append(f'    {{ "{p["name"]}", {{')
        for i, (b0, b1, b2, a1, a2) in enumerate(stages):
            h.append(f"        {{ {b0:6d}, {b1:6d}, {b2:6d}, {a1:6d}, {a2:6d} }},"
                     f"  /* stage {i + 1} */")
        h.append("    }},")
    h.append("};")
    h.append("")
    h.append("#endif /* FILTER_COEFF_H */")

    with open(os.path.join(here, "filter_coeff.h"), "w") as f:
        f.write("\n".join(h) + "\n")

    # ---- golden vectors for the RTL testbench ---------------------------
    # two-tone stimulus, shared by every preset
    try:
        with open(os.path.join(golden_dir, "test_signal_in.txt")) as f:
            stim = [int(v) for v in f.read().split()]
    except FileNotFoundError:
        stim = None

    impulse = [16384] + [0] * (IMPULSE_LEN - 1)
    for p, stages, _ in designs:
        ref = cascade_hw(impulse, stages)
        with open(os.path.join(golden_dir, f"{p['name']}.txt"), "w") as f:
            for v in ref:
                f.write(f"{v}\n")
        with open(os.path.join(golden_dir, f"{p['name']}_coeff.txt"), "w") as f:
            for (b0, b1, b2, a1, a2) in stages:
                f.write(f"{b0} {b1} {b2} {a1} {a2}\n")
        if stim is not None:
            with open(os.path.join(golden_dir, f"{p['name']}_tone.txt"), "w") as f:
                for v in cascade_hw(stim, stages):
                    f.write(f"{v}\n")

    # ---- readable reference ---------------------------------------------
    lines = [f"Butterworth coefficients, fs = {FS} Hz, format Q2.{Q} (divide by {SCALE})", ""]
    for p, stages, g in designs:
        fc = p["fc"] if isinstance(p["fc"], int) else f"{p['fc'][0]}-{p['fc'][1]}"
        lines.append(f"[{p['id']}] {p['name']}  fc = {fc} Hz, order {p['order']}")
        for i, (b0, b1, b2, a1, a2) in enumerate(stages):
            lines.append(f"    stage {i+1}: b0={b0:6d} b1={b1:6d} b2={b2:6d} "
                         f"a1={a1:6d} a2={a2:6d}")
            lines.append(f"             = {b0/SCALE:+.5f} {b1/SCALE:+.5f} {b2/SCALE:+.5f} "
                         f"{a1/SCALE:+.5f} {a2/SCALE:+.5f}")
        lines.append(f"    cascade DC gain = {g:.5f}")
        lines.append("")
    with open(os.path.join(here, "filter_coeff_ref.txt"), "w") as f:
        f.write("\n".join(lines))

    print("\nMagnitude response error vs the ideal (unquantized) design:\n")
    w = np.linspace(1.0, FS/2 - 1.0, 400)
    for p, stages, _ in designs:
        ideal = signal.butter(p["order"], p["fc"], btype=p["type"], fs=FS, output="sos")
        actual = np.array([[b0/SCALE, b1/SCALE, b2/SCALE, 1.0, a1/SCALE, a2/SCALE]
                           for (b0, b1, b2, a1, a2) in stages])
        _, hi = signal.sosfreqz(ideal,  worN=w, fs=FS)
        _, ha = signal.sosfreqz(actual, worN=w, fs=FS)
        keep = np.abs(hi) > 1e-3               # ignore deep stopband
        d = 20*np.log10(np.abs(ha[keep])) - 20*np.log10(np.abs(hi[keep]))
        print(f"  {p['name']:<12} passband/transition error: "
              f"max {np.abs(d).max():5.2f} dB")

    print("\nCross-checking the fixed-point model against scipy.signal.sosfilt")
    print("(input: 300 Hz + 2500 Hz, amplitude 12000, 512 samples)\n")
    n = np.arange(512)
    test = np.round(12000 * (0.5 * np.sin(2*np.pi*300*n/FS)
                           + 0.5 * np.sin(2*np.pi*2500*n/FS))).astype(int).tolist()
    worst = 0
    for p, stages, _ in designs:
        hw = np.array(cascade_hw(test, stages), dtype=float)
        fl = float_ref(test, stages)
        # one z^-1 per section, plus one for the inter-stage register
        err = np.abs(hw[LATENCY:] - fl[:-LATENCY])
        rms = np.sqrt(np.mean(err**2))
        worst = max(worst, err.max())
        print(f"  {p['name']:<12} max err = {err.max():7.1f} LSB   "
              f"rms = {rms:6.2f} LSB")
    print(f"\n  worst case across all presets: {worst:.1f} LSB "
          f"({20*np.log10(max(worst,1e-9)/32768):.1f} dBFS)")

    print(f"\nWrote filter_coeff.h, filter_coeff_ref.txt, and "
          f"{len(designs)*2} files in golden/")


if __name__ == "__main__":
    main()
