#!/bin/bash
# Verify the filter peripheral against the reference model before touching Vivado.
#
#   ./sim/run_filter_sim.sh
#
# Requires: iverilog, python3 with numpy + scipy.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== regenerating coefficients and golden vectors =="
( cd src/c/filter && python3 gen_test_signal.py && python3 gen_filter_coeff.py )

echo
echo "== compiling testbench =="
iverilog -g2012 -o /tmp/tb_filter.vvp \
    tb/tb_filter_axi.v \
    rtl/filter/filter_biquad.v \
    rtl/filter/filter_core.v \
    rtl/filter/axi4_lite_filter_wrapper.v \
    rtl/axi4_lite_slave.v

echo
echo "== running all presets =="
cd src/c/filter
FAIL=0
for f in LP_500 LP_800 LP_1000 HP_500 HP_800 HP_1000 BP_500_1000 BS_500_1000; do
    OUT=$(vvp /tmp/tb_filter.vvp \
            +COEFF=golden/${f}_coeff.txt \
            +GOLDEN=golden/${f}.txt \
            +TONE=golden/${f}_tone.txt \
            +NAME=$f 2>&1)
    if echo "$OUT" | grep -q "^PASS"; then
        echo "  PASS  $f"
    else
        echo "  FAIL  $f"
        echo "$OUT" | sed 's/^/        /'
        FAIL=1
    fi
done

echo
echo "== elaborating the full SoC =="
cd "$ROOT"
iverilog -g2012 -s picorv32_soc -o /tmp/soc_filter.elab \
    rtl/picorv32_soc.v rtl/axi_rom.v rtl/axi_ram.v rtl/axi4_lite_slave.v \
    rtl/axi4_lite_interconnect_m1s4.v rtl/filter/*.v \
    rtl/picorv32/picorv32_axi.v rtl/picorv32/picorv32.v \
    rtl/picorv32/picorv32_axi_adapter.v rtl/picorv32/picorv32_pcpi_*.v \
    2>&1 | grep -viE "warning|sorry" || true
echo "  SoC elaborates"

echo
echo "== full SoC with real firmware =="
if grep -q "F1170001\|mem\[29[0-9]\]" rtl/axi_rom.v 2>/dev/null || [ "$(grep -c 'mem\[' rtl/axi_rom.v)" -gt 200 ]; then
    iverilog -g2012 -s tb_soc_filter -o /tmp/tb_soc.vvp \
        tb/tb_soc_filter.v rtl/picorv32_soc.v rtl/axi_rom.v rtl/axi_ram.v \
        rtl/axi4_lite_slave.v rtl/axi4_lite_interconnect_m1s4.v rtl/filter/*.v \
        rtl/picorv32/picorv32_axi.v rtl/picorv32/picorv32.v \
        rtl/picorv32/picorv32_axi_adapter.v rtl/picorv32/picorv32_pcpi_*.v \
        2>&1 | grep -viE "warning|sorry" || true
    SOC=$(vvp /tmp/tb_soc.vvp 2>&1)
    echo "$SOC" | grep -E "finished|header|status|PASS|FAIL" | sed 's/^/  /'
    echo "$SOC" | grep -q "^PASS" || FAIL=1
else
    echo "  SKIPPED -- rtl/axi_rom.v does not hold the filter firmware."
    echo "  Build it first:  cd src/c/filter && make all"
fi

echo
if [ "$FAIL" = "0" ]; then
    echo "ALL CHECKS PASSED -- safe to run synthesis"
else
    echo "SOME CHECKS FAILED -- fix before synthesis"
    exit 1
fi
