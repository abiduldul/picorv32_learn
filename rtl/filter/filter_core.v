`default_nettype none
//
// filter_core.v
//
// Register bank + two cascaded biquad sections.  Presents the same simple
// w_REQ / r_REQ interface that gpio.v uses, so it drops straight into the
// axi4_lite_slave pattern used everywhere else in this SoC.
//
// Register map (byte offsets from the peripheral base):
//
//   0x00  CTRL      W    bit0 = clear delay line (self-clearing)
//   0x04  STATUS    R    bit0 = result ready, bit1 = coefficients written
//   0x08  DATA_IN   W    push one sample; THIS WRITE IS THE `valid` PULSE
//   0x0C  DATA_OUT  R    filtered sample, sign-extended to 32 bits

//   0x10  S1_B0     W  \
//   0x14  S1_B1     W   |
//   0x18  S1_B2     W   |  stage 1 coefficients, Q2.14, signed 16-bit
//   0x1C  S1_A1     W   |
//   0x20  S1_A2     W  /

//   0x24  S2_B0     W  \
//   0x28  S2_B1     W   |
//   0x2C  S2_B2     W   |  stage 2 coefficients
//   0x30  S2_A1     W   |
//   0x34  S2_A2     W  /

//   0x38  ID        R    0xF1170001, for a cheap "is the bus alive" check
//
// Reset defaults to a pass-through (H(z) = 1) in both stages, so the filter
// is transparent until software loads a coefficient set.
//
module filter_core #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DW         = 19,
    parameter CW         = 16,
    parameter QSHIFT     = 14
) (
    input  wire                         iCLK,
    input  wire                         iRST,      // active low

    input  wire                         w_REQ,
    input  wire                         r_REQ,
    input  wire [ADDR_WIDTH-1:0]        w_ADDR,
    input  wire [ADDR_WIDTH-1:0]        r_ADDR,
    input  wire [DATA_WIDTH-1:0]        w_DATA,
    output reg  [DATA_WIDTH-1:0]        r_DATA
);

    localparam [7:0] REG_CTRL     = 8'h00;
    localparam [7:0] REG_STATUS   = 8'h04;
    localparam [7:0] REG_DATA_IN  = 8'h08;
    localparam [7:0] REG_DATA_OUT = 8'h0C;
    localparam [7:0] REG_S1_B0    = 8'h10;
    localparam [7:0] REG_S1_B1    = 8'h14;
    localparam [7:0] REG_S1_B2    = 8'h18;
    localparam [7:0] REG_S1_A1    = 8'h1C;
    localparam [7:0] REG_S1_A2    = 8'h20;
    localparam [7:0] REG_S2_B0    = 8'h24;
    localparam [7:0] REG_S2_B1    = 8'h28;
    localparam [7:0] REG_S2_B2    = 8'h2C;
    localparam [7:0] REG_S2_A1    = 8'h30;
    localparam [7:0] REG_S2_A2    = 8'h34;
    localparam [7:0] REG_ID       = 8'h38;

    localparam [31:0] ID_VALUE    = 32'hF117_0001;
    localparam signed [CW-1:0] COEFF_ONE = 1 <<< QSHIFT;   // 1.0 in Q2.14

    wire [7:0] w_off = w_ADDR[7:0];
    wire [7:0] r_off = r_ADDR[7:0];

    /* coefficient registers */
    reg signed [CW-1:0] s1_b0, s1_b1, s1_b2, s1_a1, s1_a2;
    reg signed [CW-1:0] s2_b0, s2_b1, s2_b2, s2_a1, s2_a2;

    /* datapath */
    reg  signed [DW-1:0] x_reg;
    reg                  push;        // one-cycle valid pulse
    reg                  clr;
    reg                  result_rdy;
    reg                  coeff_dirty;

    wire signed [DW-1:0] stage1_out;  // full width -- this is the wire that
    wire signed [DW-1:0] stage2_out;  // was only 16 bits in the original

    filter_biquad #(.DW(DW), .CW(CW), .QSHIFT(QSHIFT)) stage1 (
        .clk(iCLK), .rst_n(iRST), .clr(clr), .valid(push),
        .x_in(x_reg), .y_out(stage1_out),
        .b0(s1_b0), .b1(s1_b1), .b2(s1_b2), .a1(s1_a1), .a2(s1_a2)
    );

    filter_biquad #(.DW(DW), .CW(CW), .QSHIFT(QSHIFT)) stage2 (
        .clk(iCLK), .rst_n(iRST), .clr(clr), .valid(push),
        .x_in(stage1_out), .y_out(stage2_out),
        .b0(s2_b0), .b1(s2_b1), .b2(s2_b2), .a1(s2_a1), .a2(s2_a2)
    );

    /* saturate to 16 bits only on the way out to the CPU */
    wire signed [15:0] y_sat = (stage2_out >  19'sd32767) ?  16'sd32767 :
                               (stage2_out < -19'sd32767) ? -16'sd32767 :
                                                            stage2_out[15:0];

    /* writes */
    always @(posedge iCLK) begin
        if (!iRST) begin
            s1_b0 <= COEFF_ONE; s1_b1 <= 0; s1_b2 <= 0; s1_a1 <= 0; s1_a2 <= 0;
            s2_b0 <= COEFF_ONE; s2_b1 <= 0; s2_b2 <= 0; s2_a1 <= 0; s2_a2 <= 0;
            x_reg       <= {DW{1'b0}};
            push        <= 1'b0;
            clr         <= 1'b0;
            result_rdy  <= 1'b0;
            coeff_dirty <= 1'b0;
        end else begin
            push <= 1'b0;                 // both are strictly one cycle wide
            clr  <= 1'b0;

            if (w_REQ) begin
                case (w_off)
                    REG_CTRL: begin
                        clr        <= w_DATA[0];
                        result_rdy <= 1'b0;
                    end
                    REG_DATA_IN: begin
                        // sign-extend / truncate the 32-bit bus word to DW bits
                        x_reg      <= w_DATA[DW-1:0];
                        push       <= 1'b1;
                        result_rdy <= 1'b1;
                    end
                    REG_S1_B0: begin s1_b0 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S1_B1: begin s1_b1 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S1_B2: begin s1_b2 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S1_A1: begin s1_a1 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S1_A2: begin s1_a2 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S2_B0: begin s2_b0 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S2_B1: begin s2_b1 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S2_B2: begin s2_b2 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S2_A1: begin s2_a1 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    REG_S2_A2: begin s2_a2 <= w_DATA[CW-1:0]; coeff_dirty <= 1'b1; end
                    default: ;
                endcase
            end
        end
    end

    /* reads -- combinational, so RDATA is stable while RVALID is asserted */
    always @(*) begin
        case (r_off)
            REG_STATUS:   r_DATA = {30'd0, coeff_dirty, result_rdy};
            REG_DATA_OUT: r_DATA = {{16{y_sat[15]}}, y_sat};   // sign-extend!
            REG_ID:       r_DATA = ID_VALUE;
            REG_S1_B0:    r_DATA = {{16{s1_b0[15]}}, s1_b0};
            REG_S1_B1:    r_DATA = {{16{s1_b1[15]}}, s1_b1};
            REG_S1_B2:    r_DATA = {{16{s1_b2[15]}}, s1_b2};
            REG_S1_A1:    r_DATA = {{16{s1_a1[15]}}, s1_a1};
            REG_S1_A2:    r_DATA = {{16{s1_a2[15]}}, s1_a2};
            REG_S2_B0:    r_DATA = {{16{s2_b0[15]}}, s2_b0};
            REG_S2_B1:    r_DATA = {{16{s2_b1[15]}}, s2_b1};
            REG_S2_B2:    r_DATA = {{16{s2_b2[15]}}, s2_b2};
            REG_S2_A1:    r_DATA = {{16{s2_a1[15]}}, s2_a1};
            REG_S2_A2:    r_DATA = {{16{s2_a2[15]}}, s2_a2};
            default:      r_DATA = 32'h0000_0000;
        endcase
    end

endmodule
`default_nettype wire
