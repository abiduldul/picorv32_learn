`default_nettype none
//
// filter_biquad.v
//
// One Direct Form I second-order IIR section:
//
//   y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
//
// Coefficients are Q2.QSHIFT fixed point (divide the integer by 2**QSHIFT to
// read the real value).  The section is coefficient-agnostic: load Butterworth
// coefficients and it is a Butterworth section, load Chebyshev and it is a
// Chebyshev section.
//
// Derived from adjipangestu7/FPGA_Butterworth_Filter with four changes:
//   1. synchronous reset + soft clear, so coefficients can be swapped at runtime
//   2. DW-bit (19) ports instead of 16, so a cascade does not lose resolution
//      on the wire between sections
//   3. round-to-nearest on the Q-shift instead of truncation (no DC bias)
//   4. explicit saturation of the state register instead of silent truncation
//
// One sample is consumed per `valid` pulse, NOT per clock.
//
module filter_biquad #(
    parameter DW     = 19,   // sample / state width
    parameter CW     = 16,   // coefficient width
    parameter QSHIFT = 14    // coefficient fractional bits
) (
    input  wire                     clk,
    input  wire                     rst_n,     // active low, synchronous
    input  wire                     clr,       // soft clear of the delay line
    input  wire                     valid,     // one pulse = one sample

    input  wire signed [DW-1:0]     x_in,
    output wire signed [DW-1:0]     y_out,

    input  wire signed [CW-1:0]     b0,
    input  wire signed [CW-1:0]     b1,
    input  wire signed [CW-1:0]     b2,
    input  wire signed [CW-1:0]     a1,
    input  wire signed [CW-1:0]     a2
);

    localparam PW   = DW + CW;        // 35: one product
    localparam ACCW = DW + CW + 3;    // 38: five products summed

    // Saturation limits, symmetric.  Keep a DW-wide copy for the result and an
    // ACCW-wide copy for the comparison: mixing widths in a comparison is how
    // signedness bugs get in.
    localparam signed [DW-1:0]   SAT_MAX   =  (1 <<< (DW-1)) - 1;   // +262143
    localparam signed [DW-1:0]   SAT_MIN   = -((1 <<< (DW-1)) - 1); // -262143
    localparam signed [ACCW-1:0] SAT_MAX_E =  (1 <<< (DW-1)) - 1;
    localparam signed [ACCW-1:0] SAT_MIN_E = -((1 <<< (DW-1)) - 1);
    localparam signed [ACCW-1:0] ROUND     =  1 <<< (QSHIFT-1);     // +8192

    /* delay line */
    reg signed [DW-1:0] x_curr, x_d1, x_d2;
    reg signed [DW-1:0] y_d1,   y_d2;

    /* products -- Vivado infers DSP48E1 for each of these */
    wire signed [PW-1:0] mul_b0 = x_curr * b0;
    wire signed [PW-1:0] mul_b1 = x_d1   * b1;
    wire signed [PW-1:0] mul_b2 = x_d2   * b2;
    // Negate the product rather than the coefficient: -a1 would overflow if a1
    // were exactly -32768.
    wire signed [PW-1:0] mul_a1 = -(y_d1 * a1);
    wire signed [PW-1:0] mul_a2 = -(y_d2 * a2);

    // $signed() on every term: a bare concatenation is UNSIGNED in Verilog, and
    // one unsigned operand poisons the whole expression.
    wire signed [ACCW-1:0] acc_sum = $signed(mul_b0) + $signed(mul_b1)
                                   + $signed(mul_b2) + $signed(mul_a1)
                                   + $signed(mul_a2);

    /* round to nearest, then undo the Q scaling */
    wire signed [ACCW-1:0] acc_rnd = acc_sum + ROUND;
    wire signed [ACCW-1:0] acc_shf = acc_rnd >>> QSHIFT;

    /* saturate into DW bits instead of silently dropping the high bits */
    wire signed [DW-1:0] y_next = (acc_shf > SAT_MAX_E) ? SAT_MAX :
                                  (acc_shf < SAT_MIN_E) ? SAT_MIN :
                                                          acc_shf[DW-1:0];

    always @(posedge clk) begin
        if (!rst_n || clr) begin
            x_curr <= {DW{1'b0}};
            x_d1   <= {DW{1'b0}};
            x_d2   <= {DW{1'b0}};
            y_d1   <= {DW{1'b0}};
            y_d2   <= {DW{1'b0}};
        end else if (valid) begin
            x_curr <= x_in;
            x_d1   <= x_curr;
            x_d2   <= x_d1;
            y_d1   <= y_next;
            y_d2   <= y_d1;
        end
    end

    assign y_out = y_d1;

endmodule
`default_nettype wire
