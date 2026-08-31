`timescale 1ns / 1ps
`default_nettype wire
//
// tb_soc_filter.v
//
// Runs the real compiled firmware on picorv32 inside the full SoC and checks
// what the program leaves in ram_output.  This is the end-to-end proof: CPU
// fetches from ROM, drives the filter over AXI, writes results back.
//
// Run:
//   iverilog -g2012 -s tb_soc_filter -o soc.vvp sim/tb_soc_filter.v rtl/...
//   vvp soc.vvp
//
module tb_soc_filter;

    localparam integer SIG_LEN   = 256;
    localparam integer HDR_DATA  = 4;      // packed samples start at word 4
    localparam integer MAX_CYCLE = 4_000_000;

    reg clk = 0, rst_n = 0;
    wire trap, LED;

    always #5 clk = ~clk;                  // 100 MHz

    picorv32_soc dut (.clk(clk), .rst_n(rst_n), .trap(trap), .LED(LED));

    integer cycles = 0;
    integer i, errors, first_bad, diff;
    integer fd, code, v;
    integer gref [0:SIG_LEN-1];
    reg [31:0] word;
    reg signed [15:0] got16;
    integer got, want;
    reg done;

    initial begin
        errors = 0; first_bad = -1; done = 0;

        fd = $fopen("src/c/filter/golden/LP_500_tone.txt", "r");
        if (fd == 0) begin
            $display("FATAL: golden/LP_500_tone.txt not found");
            $finish;
        end
        for (i = 0; i < SIG_LEN; i = i + 1) begin
            code = $fscanf(fd, "%d", v);
            gref[i] = v;
        end
        $fclose(fd);

        rst_n = 0;
        repeat (20) @(posedge clk);
        rst_n = 1;

        // wait for the program to publish its header word
        while (!done && cycles < MAX_CYCLE) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (trap) begin
                $display("FAIL: CPU trapped after %0d cycles", cycles);
                $finish;
            end
            if (dut.ram_output.mem[0][31:8] == 24'hF11700)
                done = 1;
        end

        if (!done) begin
            $display("FAIL: firmware did not finish within %0d cycles", MAX_CYCLE);
            $display("      ram_output[0] = %h  [1] = %h",
                     dut.ram_output.mem[0], dut.ram_output.mem[1]);
            $finish;
        end

        $display("");
        $display("firmware finished after %0d cycles (%0.2f us at 100 MHz)",
                 cycles, cycles / 100.0);
        $display("  header  = %h  (preset %0d)",
                 dut.ram_output.mem[0], dut.ram_output.mem[0][7:0]);
        $display("  length  = %0d", dut.ram_output.mem[1]);
        $display("  status  = %h  (0 = coefficients read back correctly)",
                 dut.ram_output.mem[2]);
        if (dut.ram_output.mem[2] !== 32'h0) errors = errors + 1;

        // The program aligns dst[n] with src[n], so its output is the model
        // output shifted forward by FILT_LATENCY = 3.
        for (i = 0; i < SIG_LEN - 3; i = i + 1) begin
            word = dut.ram_output.mem[HDR_DATA + (i >> 1)];
            got16 = (i[0]) ? word[31:16] : word[15:0];
            got  = got16;
            want = gref[i + 3];
            diff = got - want;
            if (diff < 0) diff = -diff;
            if (diff > 0) begin
                errors = errors + 1;
                if (first_bad < 0) first_bad = i;
                if (errors <= 6)
                    $display("  n=%0d  soc=%0d  ref=%0d", i, got, want);
            end
        end

        $display("");
        if (errors == 0)
            $display("PASS  full SoC: %0d filtered samples match the model exactly",
                     SIG_LEN - 3);
        else
            $display("FAIL  full SoC: %0d mismatches, first at n=%0d",
                     errors, first_bad);
        $display("");
        $finish;
    end

endmodule
