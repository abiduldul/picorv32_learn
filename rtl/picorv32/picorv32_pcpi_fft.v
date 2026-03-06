`default_nettype none

module picorv32_pcpi_fft (
    input  wire        clk,
    input  wire        resetn,

    // PCPI Interface (PicoRV32 standard)
    input  wire        pcpi_valid,   // high when CPU issues an instruction
    input  wire [31:0] pcpi_insn,    // full 32-bit instruction word
    input  wire [31:0] pcpi_rs1,     // value of rs1 (multiplicand)
    input  wire [31:0] pcpi_rs2,     // value of rs2 (multiplier)
    output reg         pcpi_wr,      // high to write result back to rd
    output reg  [31:0] pcpi_rd,      // result written to rd
    output reg         pcpi_ready,   // pulse high when instruction is done
    output reg         pcpi_wait     // held low — we never stall the CPU
);

    // -------------------------------------------------------------------------
    // Instruction Decode
    // -------------------------------------------------------------------------
    wire [6:0] insn_opcode = pcpi_insn[6:0];
    wire [2:0] insn_funct3 = pcpi_insn[14:12];
    wire [6:0] insn_funct7 = pcpi_insn[31:25];

    // custom-0 opcode = 7'b000_1011
    localparam CUSTOM0_OPCODE = 7'b000_1011;

    wire is_cmul = (insn_opcode == CUSTOM0_OPCODE) &&
                   (insn_funct3 == 3'h0)           &&
                   (insn_funct7 == 7'h00);

    wire signed [31:0] operand_a = $signed(pcpi_rs1);
    wire signed [31:0] operand_b = $signed(pcpi_rs2);
    wire signed [31:0] product   = operand_a * operand_b;

    always @(posedge clk) begin
        pcpi_wr    <= 1'b0;
        pcpi_ready <= 1'b0;
        pcpi_wait  <= 1'b0;
        pcpi_rd    <= 32'h0;

        if (resetn && pcpi_valid && is_cmul) begin
            pcpi_rd    <= product; 
            pcpi_wr    <= 1'b1;     // write result back to rd
            pcpi_ready <= 1'b1;     // tell CPU we are done
        end
    end

endmodule