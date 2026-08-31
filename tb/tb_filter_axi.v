`timescale 1ns / 1ps
`default_nettype wire
//
// tb_filter_axi.v
//
// Drives real AXI4-Lite transactions into axi4_lite_filter_wrapper, loads a
// Butterworth coefficient set, pushes an impulse through, and compares the
// response sample-by-sample against a golden vector produced by the bit-exact
// Python model (which is itself checked against scipy.signal.sosfilt).
//
// Run:
//   iverilog -g2012 -o tb.vvp sim/tb_filter_axi.v rtl/filter/*.v rtl/axi4_lite_slave.v
//   vvp tb.vvp +COEFF=... +GOLDEN=...
//
module tb_filter_axi;

    localparam integer N       = 64;
    localparam integer NS      = 256;   // two-tone stimulus length
    localparam integer LATENCY = 0;    // golden vectors already model the pipeline

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;              // 100 MHz

    /* AXI master side */
    reg         AWVALID = 0, WVALID = 0, BREADY = 0, ARVALID = 0, RREADY = 0;
    reg  [31:0] AWADDR = 0, WDATA = 0, ARADDR = 0;
    reg  [3:0]  WSTRB = 4'hF;
    wire        AWREADY, WREADY, BVALID, ARREADY, RVALID;
    wire [1:0]  BRESP, RRESP;
    wire [31:0] RDATA;

    axi4_lite_filter_wrapper #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) dut (
        .iCLK(clk), .iRST(rst_n),
        .s_AWVALID(AWVALID), .s_AWPROT(3'b0), .s_AWADDR(AWADDR), .s_AWREADY(AWREADY),
        .s_WVALID(WVALID), .s_WDATA(WDATA), .s_WSTRB(WSTRB), .s_WREADY(WREADY),
        .s_BREADY(BREADY), .s_BVALID(BVALID), .s_BRESP(BRESP),
        .s_ARVALID(ARVALID), .s_ARPROT(3'b0), .s_ARADDR(ARADDR), .s_ARREADY(ARREADY),
        .s_RREADY(RREADY), .s_RVALID(RVALID), .s_RRESP(RRESP), .s_RDATA(RDATA)
    );

    /* ---- AXI helpers ---------------------------------------------------- */
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            AWADDR <= addr; AWVALID <= 1'b1;
            WDATA  <= data; WVALID  <= 1'b1; WSTRB <= 4'hF;
            BREADY <= 1'b1;
            @(posedge clk);
            while (!(AWVALID && AWREADY)) @(posedge clk);
            AWVALID <= 1'b0;
            while (!(WVALID && WREADY)) @(posedge clk);
            WVALID <= 1'b0;
            while (!(BVALID && BREADY)) @(posedge clk);
            @(posedge clk);
            BREADY <= 1'b0;
        end
    endtask

    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            ARADDR <= addr; ARVALID <= 1'b1; RREADY <= 1'b1;
            @(posedge clk);
            while (!(ARVALID && ARREADY)) @(posedge clk);
            ARVALID <= 1'b0;
            while (!(RVALID && RREADY)) @(posedge clk);
            data = RDATA;
            @(posedge clk);
            RREADY <= 1'b0;
        end
    endtask

    /* ---- register offsets ----------------------------------------------- */
    localparam CTRL = 32'h00, STATUS = 32'h04, DATA_IN = 32'h08, DATA_OUT = 32'h0C;
    localparam S1_B0 = 32'h10, S2_B0 = 32'h24, ID = 32'h38;

    integer coeff  [0:9];     // s1: b0 b1 b2 a1 a2, s2: b0 b1 b2 a1 a2
    integer golden [0:N-1];
    integer stim   [0:NS-1];
    integer sref   [0:NS-1];
    integer fo;

    integer i, errors, first_bad, diff, fd, code, v;
    reg [31:0] rd;
    reg signed [31:0] got, want;
    reg [255:0] coeff_file, golden_file, tone_file, tname;

    initial begin
        errors = 0; first_bad = -1;

        if (!$value$plusargs("COEFF=%s",  coeff_file))  coeff_file  = "golden/LP_500_coeff.txt";
        if (!$value$plusargs("GOLDEN=%s", golden_file)) golden_file = "golden/LP_500.txt";
        if (!$value$plusargs("TONE=%s",   tone_file))   tone_file   = "golden/LP_500_tone.txt";
        if (!$value$plusargs("NAME=%s",   tname))       tname       = "LP_500";

        fd = $fopen(coeff_file, "r");
        if (fd == 0) begin $display("FATAL: cannot open %0s", coeff_file); $finish; end
        for (i = 0; i < 10; i = i + 1) begin
            code = $fscanf(fd, "%d", v);
            if (code != 1) begin $display("FATAL: short coeff file"); $finish; end
            coeff[i] = v;
        end
        $fclose(fd);

        fd = $fopen(golden_file, "r");
        if (fd == 0) begin $display("FATAL: cannot open %0s", golden_file); $finish; end
        for (i = 0; i < N; i = i + 1) begin
            code = $fscanf(fd, "%d", v);
            if (code != 1) begin $display("FATAL: short golden file"); $finish; end
            golden[i] = v;
        end
        $fclose(fd);

        rst_n = 0;
        repeat (8) @(posedge clk);
        rst_n = 1;
        repeat (4) @(posedge clk);

        /* sanity: is the peripheral actually on the bus? */
        axi_read(ID, rd);
        if (rd !== 32'hF117_0001) begin
            $display("FAIL: ID register read back %h, expected F1170001", rd);
            errors = errors + 1;
        end

        /* load coefficients */
        for (i = 0; i < 5; i = i + 1)
            axi_write(S1_B0 + i*4, coeff[i]     & 32'h0000FFFF);
        for (i = 0; i < 5; i = i + 1)
            axi_write(S2_B0 + i*4, coeff[i + 5] & 32'h0000FFFF);

        /* read one back to prove the register bank is wired right */
        axi_read(S1_B0, rd);
        if ($signed(rd) !== coeff[0]) begin
            $display("FAIL: S1_B0 read back %0d, expected %0d", $signed(rd), coeff[0]);
            errors = errors + 1;
        end

        /* clear the delay line, then push the impulse */
        axi_write(CTRL, 32'h1);
        repeat (4) @(posedge clk);

        for (i = 0; i < N + LATENCY; i = i + 1) begin
            axi_write(DATA_IN, (i == 0) ? 32'd16384 : 32'd0);
            axi_read(DATA_OUT, rd);

            if (i >= LATENCY) begin
                got  = $signed(rd);
                want = golden[i - LATENCY];
                diff = got - want;
                if (diff < 0) diff = -diff;
                if (diff > 1) begin
                    errors = errors + 1;
                    if (first_bad < 0) first_bad = i - LATENCY;
                    if (errors <= 8)
                        $display("  n=%0d  rtl=%0d  ref=%0d  diff=%0d",
                                 i - LATENCY, got, want, got - want);
                end
            end
        end

        /* ---- two-tone run: same coefficients, real signal ---------------- */
        fd = $fopen("golden/test_signal_in.txt", "r");
        if (fd != 0) begin
            for (i = 0; i < NS; i = i + 1) begin
                code = $fscanf(fd, "%d", v); stim[i] = v;
            end
            $fclose(fd);
            fd = $fopen(tone_file, "r");
            for (i = 0; i < NS; i = i + 1) begin
                code = $fscanf(fd, "%d", v); sref[i] = v;
            end
            $fclose(fd);

            axi_write(CTRL, 32'h1);
            repeat (4) @(posedge clk);

            fo = $fopen("golden/rtl_out.txt", "w");
            for (i = 0; i < NS; i = i + 1) begin
                axi_write(DATA_IN, stim[i] & 32'hFFFFFFFF);
                axi_read(DATA_OUT, rd);
                got = $signed(rd);
                $fwrite(fo, "%0d\n", got);
                if (got !== sref[i]) begin
                    errors = errors + 1;
                    if (errors <= 4)
                        $display("  two-tone n=%0d rtl=%0d ref=%0d", i, got, sref[i]);
                end
            end
            $fclose(fo);
            $display("  two-tone run: %0d samples written to golden/rtl_out.txt", NS);
        end

        $display("");
        if (errors == 0)
            $display("PASS  %0s: %0d samples match the reference", tname, N);
        else
            $display("FAIL  %0s: %0d mismatches, first at n=%0d", tname, errors, first_bad);
        $display("");
        $finish;
    end


    initial begin
        #2_000_000;
        $display("FAIL: timeout -- the bus is probably hung");
        $finish;
    end

endmodule
