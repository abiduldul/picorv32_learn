`timescale 1ns / 1ps

module tb_picorv32_soc();

    reg clk;
    reg rst_n;
    wire trap;
    integer file_ptr;
    integer i;
    reg [64:0] cyclecount;

    // Clock
    always #1 clk = ~clk;

    // Instansiasi SoC (Port menjadi lebih simpel)
    picorv32_soc dut (
        .clk(clk),
        .rst_n(rst_n),
        .trap(trap),
        .LED()
    );
    // initial begin
    //     $dumpfile("sim/tb_picorv32_soc.vcd");
    //     $dumpvars(0, tb_picorv32_soc);
    // end

    initial begin
        clk = 0;
        
        rst_n = 0;
        #100;
        rst_n = 1;
        
        $display("Starting Simulation...");
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cyclecount <= 0;
        end else begin
            cyclecount <= cyclecount + 1;
        end
    end

    // --- BLOK PENYIMPANAN DATA ---
    // Dipicu saat sinyal 'trap' (ebreak) aktif
    always @(posedge trap) begin
        $display("CPU Trap detected via EBREAK.");
        $display("Dumping Output RAM content to file...");
        
        file_ptr = $fopen("output_samples.txt", "w");
        
        if (file_ptr) begin
            // Mengakses hirarki internal Verilog:
            // dut (SoC) -> ram_output (Instance Name) -> mem (Array Reg)
            // Kita loop n kali sesuai jumlah data di main.c
            for (i = 0; i < 1024; i = i + 1) begin
                // Menulis data dari RAM ke file
                $fwrite(file_ptr, "%d\n", $signed(dut.ram_output.mem[i]));
                // $display("Address %d: %d", i, $signed(dut.ram_output.mem[i]));
            end
            
            $fclose(file_ptr);
            $display("File output_samples.txt saved successfully.");
        end else begin
            $display("Error: Could not open output file.");
        end

        $display("Total Cycles: %d", cyclecount);
        #100;
        $finish;
    end

endmodule