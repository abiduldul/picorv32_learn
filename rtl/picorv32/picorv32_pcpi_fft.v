module picorv32_pcpi_fft (
    input wire clk,
    input wire resetn,
    
    // Interface PCPI dari PicoRV32
    input wire        pcpi_valid,
    input wire [31:0] pcpi_insn,
    input wire [31:0] pcpi_rs1,
    input wire [31:0] pcpi_rs2,
    
    output reg        pcpi_wr,
    output reg [31:0] pcpi_rd,
    output reg        pcpi_wait,
    output reg        pcpi_ready
);

    // Definisi Opcode Custom-0 (RISC-V Standard)
    localparam [6:0] OPCODE_CUSTOM0 = 7'b0001011;

    // --- Unpacking Data (Memecah 32-bit jadi dua 16-bit) ---
    // Gunakan $signed agar Verilog tahu ini bilangan negatif/positif (Two's Complement)
    wire signed [15:0] d_real = pcpi_rs1[31:16];
    wire signed [15:0] d_imag = pcpi_rs1[15:0];
    wire signed [15:0] t_cos  = pcpi_rs2[31:16];
    wire signed [15:0] t_sin  = pcpi_rs2[15:0];

    // --- The Math (Logic Matematika FFT) ---
    // Rumus: 
    // TR = (Real * Cos - Imag * Sin) >> 10
    // TI = (Real * Sin + Imag * Cos) >> 10
    
    // Hasil sementara (32-bit karena perkalian 16x16)
    wire signed [31:0] mul_rc = d_real * t_cos;
    wire signed [31:0] mul_is = d_imag * t_sin;
    wire signed [31:0] mul_rs = d_real * t_sin;
    wire signed [31:0] mul_ic = d_imag * t_cos;

    // 1. Hitung hasil mentah di 32-bit dulu
    wire signed [31:0] raw_res_real = (mul_rc - mul_is) >>> 10;
    wire signed [31:0] raw_res_imag = (mul_rs + mul_ic) >>> 10;
    
    reg signed [15:0] sat_res_real;
    reg signed [15:0] sat_res_imag;

    // 2. Cek apakah hasil melebihi 16-bit?
    always @(*) begin
        // Saturasi Real
        if (raw_res_real > 32767) 
            sat_res_real = 32767;      // Mentok Positif
        else if (raw_res_real < -32768) 
            sat_res_real = -32768;     // Mentok Negatif
        else 
            sat_res_real = raw_res_real[15:0]; // Data Valid

        // Saturasi Imag
        if (raw_res_imag > 32767) 
            sat_res_imag = 32767;
        else if (raw_res_imag < -32768) 
            sat_res_imag = -32768;
        else 
            sat_res_imag = raw_res_imag[15:0];
    end

    // --- PCPI Handshake Logic ---
    always @(posedge clk) begin
        if (!resetn) begin
            pcpi_wr <= 0;
            pcpi_ready <= 0;
            pcpi_wait <= 0;
        end else begin
            pcpi_wr <= 0;
            pcpi_ready <= 0;
            
            if (pcpi_valid && pcpi_insn[6:0] == OPCODE_CUSTOM0) begin
                // Gunakan hasil yang sudah disaturasi
                pcpi_rd <= {sat_res_real, sat_res_imag}; 
                pcpi_wr <= 1;
                pcpi_ready <= 1;
            end
        end
    end

endmodule