/**
 * Modul: picorv32_pcpi_bitrev
 * Deskripsi: Modul ekstensi PCPI untuk Bit Reversal (1-Siklus Kombinasional)
 *
 * Sinyal ini disesuaikan dengan antarmuka PCPI 10-sinyal standar
 * yang ditemukan di picorv32.v.
 */

module picorv32_pcpi_bitrev (
    // Input Global
    input           clk,
    input           resetn,

    // Input dari PicoRV32 (Antarmuka PCPI)
    input           pcpi_valid,   // Instruksi kustom baru valid
    input  [31:0]   pcpi_insn,    // 32-bit instruksi itu sendiri
    input  [31:0]   pcpi_rs1,     // Data dari register sumber 1
    input  [31:0]   pcpi_rs2,     // Data dari register sumber 2 (tidak dipakai di sini)

    // Output ke PicoRV32 (Antarmuka PCPI)
    output reg          pcpi_wr,      // 1: Sinyalkan 'write-back' ke register file
    output reg [31:0]   pcpi_rd,      // Data yang akan di-write-back
    output reg          pcpi_wait,    // 1: Minta CPU untuk 'stall' (menunggu)
    output reg          pcpi_ready    // 1: Sinyalkan operasi multi-cycle selesai
);

    // --- 1. Logika Dekoding Instruksi ---
    // Mari kita definisikan instruksi 'brev' kita (R-type)
    // Opcode: custom-0 (0b0001011)
    // funct3: 0b001
    // funct7: 0b0000001

    wire is_brev_instr = pcpi_valid && 
                         (pcpi_insn[6:0]   == 7'b0001011) && // OPCODE custom-0
                         (pcpi_insn[14:12] == 3'b001)      && // funct3
                         (pcpi_insn[31:25] == 7'b0000001);   // funct7

    // --- 2. Logika Inti (Bit Reversal) ---
    // Ini murni kombinasional. Tidak perlu state atau clock.
    // Kita gunakan 'reg' di sini agar bisa di-assign di dalam 'always @(*)'
    reg [31:0] reversed_val;

    integer i;
    always @(*) begin
        // Logika pembalikan bit kombinasional
        for (i = 0; i < 32; i = i + 1) begin
            reversed_val[i] = pcpi_rs1[31 - i];
        end
    end

    // --- 3. Logika Handshake PCPI (Kombinasional / 1-Siklus) ---
    // Ini adalah bagian terpenting yang disesuaikan
    // dengan sinyal pcpi_wait, pcpi_ready, dan pcpi_wr.
    
    always @(*) begin
        if (is_brev_instr) begin
            // --- Jika ini adalah instruksi 'brev' kita ---
            
            // 1. pcpi_wait: Apakah CPU perlu menunggu (stall)?
            //    Tidak, karena ini adalah operasi kombinasional
            //    yang selesai dalam siklus ini juga.
            pcpi_wait = 1'b0;
            
            // 2. pcpi_ready: Apakah operasi multi-cycle selesai?
            //    Tidak, ini bukan operasi multi-cycle.
            pcpi_ready = 1'b1;
            
            // 3. pcpi_wr: Apakah kita mau menulis hasil ke register file?
            //    Ya. Kita aktifkan sinyal 'write'.
            pcpi_wr = 1'b1;
            
            // 4. pcpi_rd: Data apa yang mau kita tulis?
            //    Hasil yang sudah dibalik.
            pcpi_rd = reversed_val;
            
        end else begin
            // --- Jika ini BUKAN instruksi kita ---
            // Set semua output ke '0' (default state)
            pcpi_wait = 1'b0;
            pcpi_ready = 1'b0;
            pcpi_wr = 1'b0;
            pcpi_rd = 32'b0;
        end
    end
endmodule