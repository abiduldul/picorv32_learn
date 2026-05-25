// =============================================================================
// INSTRUCTION SET:
//   mshift  opcode=0x0B funct3=0  rd = rs1 * rs2 (lower 32-bit, NO shift)
//   bload   opcode=0x2B funct3=0  stores rs1=real[pair], rs2=imag[pair]
//   bfly    opcode=0x2B funct3=1  rd = (real*rs1 - imag*rs2) >>> FIXED_SHIFT
//                                  internally caches ti = (real*rs2 + imag*rs1) >>> FIXED_SHIFT
//   bget    opcode=0x2B funct3=2  rd = cached ti
// =============================================================================

module picorv32_pcpi_fft #(
    parameter FIXED_SHIFT = 10
) (
    input  wire        clk,
    input  wire        resetn,

    input  wire        pcpi_valid,
    input  wire [31:0] pcpi_insn,
    input  wire [31:0] pcpi_rs1,
    input  wire [31:0] pcpi_rs2,
    output reg         pcpi_wr,
    output reg  [31:0] pcpi_rd,
    output reg         pcpi_ready,
    output reg         pcpi_wait
);

    // -------------------------------------------------------------------------
    // Instruction Decode
    // -------------------------------------------------------------------------
    wire [6:0] insn_opcode = pcpi_insn[6:0];
    wire [2:0] insn_funct3 = pcpi_insn[14:12];

    localparam CUSTOM0_OPCODE = 7'b000_1011; // 0x0B — mshift
    localparam CUSTOM1_OPCODE = 7'b010_1011; // 0x2B — bload/bfly/bget

    wire is_mshift = (insn_opcode == CUSTOM0_OPCODE) && (insn_funct3 == 3'h0);
    wire is_bload  = (insn_opcode == CUSTOM1_OPCODE) && (insn_funct3 == 3'h0);
    wire is_bfly   = (insn_opcode == CUSTOM1_OPCODE) && (insn_funct3 == 3'h1);
    wire is_bget   = (insn_opcode == CUSTOM1_OPCODE) && (insn_funct3 == 3'h2);
    wire is_ours   = is_mshift || is_bload || is_bfly || is_bget;

    // -------------------------------------------------------------------------
    // Internal State Registers
    // -------------------------------------------------------------------------
    reg signed [31:0] stored_real; // loaded by bload, used by bfly
    reg signed [31:0] stored_imag; // loaded by bload, used by bfly
    reg signed [31:0] cached_ti;   // computed by bfly, returned by bget

    // -------------------------------------------------------------------------
    // Combinational Arithmetic — all 4 butterfly multiplies in parallel
    //
    // Uses stored_real/imag (from previous bload) and pcpi_rs1=c, pcpi_rs2=s
    //
    // Forward FFT:
    //   tr = (real*c - imag*s) >>> FIXED_SHIFT
    //   ti = (real*s + imag*c) >>> FIXED_SHIFT
    //
    // Inverse FFT (caller passes -s as rs2):
    //   tr = (real*c - imag*(-s)) >>> 10 = (real*c + imag*s) >>> 10  ✓
    //   ti = (real*(-s) + imag*c) >>> 10 = (imag*c - real*s) >>> 10  ✓
    // -------------------------------------------------------------------------
    wire signed [63:0] s_real_64 = $signed(stored_real);
    wire signed [63:0] s_imag_64 = $signed(stored_imag);
    wire signed [63:0] c_64      = $signed(pcpi_rs1);   // cosine twiddle
    wire signed [63:0] s_64      = $signed(pcpi_rs2);   // sine twiddle

    wire signed [63:0] r_c = s_real_64 * c_64; // real * c
    wire signed [63:0] i_s = s_imag_64 * s_64; // imag * s
    wire signed [63:0] r_s = s_real_64 * s_64; // real * s
    wire signed [63:0] i_c = s_imag_64 * c_64; // imag * c

    wire signed [63:0] tr_64     = r_c - i_s;
    wire signed [63:0] ti_64     = r_s + i_c;

    wire signed [31:0] tr_result = tr_64[FIXED_SHIFT +: 32]; // arithmetic >> 10
    wire signed [31:0] ti_result = ti_64[FIXED_SHIFT +: 32]; // arithmetic >> 10

    // -------------------------------------------------------------------------
    // FIX 1: mshift — pure 32-bit multiply, NO shift baked in
    // The C code does >> FIXED_SHIFT explicitly, so we must NOT do it here.
    // Before this fix: (a*b) >> 10 in RTL, then >> 10 again in C = >> 20 total.
    // -------------------------------------------------------------------------
    wire signed [63:0] mshift_full = $signed(pcpi_rs1) * $signed(pcpi_rs2);
    wire signed [31:0] mshift_result = mshift_full[31:0]; // lower 32 bits only

    // -------------------------------------------------------------------------
    // FIX 2: Registered PCPI outputs (was combinational before)
    //
    // Why this matters:
    //   Combinational pcpi_ready can glitch when pcpi_valid or decode signals
    //   change mid-cycle. PicoRV32 samples pcpi_ready at the clock edge —
    //   a glitch before the edge can cause it to incorrectly accept/reject.
    //   Registered outputs guarantee clean, stable signals at every clock edge.
    //
    // Timing with registered outputs:
    //   Cycle N:   instruction arrives on pcpi_valid
    //   Cycle N+1: pcpi_ready=1, pcpi_rd=result captured by CPU
    //   This adds 1 cycle latency but is fully correct and stable.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        // Default: deassert every cycle
        pcpi_wr    <= 1'b0;
        pcpi_ready <= 1'b0;
        pcpi_wait  <= 1'b0;
        pcpi_rd    <= 32'h0;

        if (!resetn) begin
            stored_real <= 32'sd0;
            stored_imag <= 32'sd0;
            cached_ti   <= 32'sd0;
        end
        else if (pcpi_valid && is_ours) begin

            // ------------------------------------------------------------------
            // mshift: pure multiply, return lower 32 bits
            // Used by GCC automatically for all a*b in C code
            // C code handles >> FIXED_SHIFT explicitly — do NOT shift here
            // ------------------------------------------------------------------
            if (is_mshift) begin
                pcpi_rd    <= mshift_result;
                pcpi_wr    <= 1'b1;
                pcpi_ready <= 1'b1;
            end

            // ------------------------------------------------------------------
            // bload: store real[pair] and imag[pair] into internal registers
            // rs1 = real[pair], rs2 = imag[pair]
            // FIX 3: assert pcpi_wr=1 with rd=0 so PicoRV32 properly acks
            // ------------------------------------------------------------------
            else if (is_bload) begin
                stored_real <= $signed(pcpi_rs1);
                stored_imag <= $signed(pcpi_rs2);
                pcpi_rd     <= 32'h0;
                pcpi_wr     <= 1'b1; // FIX 3: was 0 before
                pcpi_ready  <= 1'b1;
            end

            // ------------------------------------------------------------------
            // bfly: compute butterfly using stored real/imag and incoming c/s
            // rs1 = c (cosine twiddle factor)
            // rs2 = s (sine twiddle factor, pass -s for IFFT)
            // rd  = tr = (real*c - imag*s) >>> FIXED_SHIFT
            // internally saves ti = (real*s + imag*c) >>> FIXED_SHIFT
            //
            // Note: stored_real/imag were written at END of previous bload cycle.
            // Since PicoRV32 takes >= 1 cycle between instructions, bfly always
            // sees the correctly updated stored values. Safe by construction.
            // ------------------------------------------------------------------
            else if (is_bfly) begin
                cached_ti  <= ti_result; // save ti for bget
                pcpi_rd    <= tr_result; // return tr to CPU
                pcpi_wr    <= 1'b1;
                pcpi_ready <= 1'b1;
            end

            // ------------------------------------------------------------------
            // bget: return ti cached by previous bfly
            // rd = ti
            // ------------------------------------------------------------------
            else if (is_bget) begin
                pcpi_rd    <= cached_ti;
                pcpi_wr    <= 1'b1;
                pcpi_ready <= 1'b1;
            end

        end
    end

endmodule