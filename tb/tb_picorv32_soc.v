`timescale 1ns / 1ps
module tb_picorv32_soc();

    reg clk;
    reg rst_n;
    reg [64:0] cycle_count;
    wire trap;
    always #5 clk = ~clk;

    picorv32_soc dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .trap   (trap)
    );

    initial begin
        $dumpfile("sim/tb_picorv32_soc.vcd");
        $dumpvars(0, tb_picorv32_soc);
    end

    initial begin
        cycle_count = 0;
        clk = 0;
        rst_n = 1;   // 1. Mulai dalam mode reset
        #100;        // 2. Tahan reset selama 100ns
        rst_n = 0;   // 3. Lepas reset, CPU mulai eksekusi program
        
        // JANGAN reset lagi. Biarkan simulasi berjalan
        // sampai sinyal 'trap' aktif.
        
        $display("Monitoring AXI transactions...");
    end

    always @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end
    end

    always @(posedge trap) begin
        $display("cycle count = %d", cycle_count);
        #100;
        $finish;
    end
endmodule