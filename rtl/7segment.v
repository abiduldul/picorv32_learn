// Kontroler 8-digit 7-segment Nexys A7 (common anode, segmen & anoda active-LOW).
// CPU cukup menulis 'value' (32-bit = 8 nibble hex) sekali; modul me-refresh sendiri.
module seven_seg #(
    parameter integer REFRESH_BITS = 16  // 2^16/100MHz ~0.66ms/digit -> ~190Hz/siklus
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] value,   // 8 digit hex: value[3:0]=digit kanan ... value[31:28]=digit kiri
    output reg  [6:0]  seg,     // {CG..CA} -> seg[0]=CA(a) .. seg[6]=CG(g), active low
    output wire        dp,      // titik desimal, active low (dimatikan)
    output reg  [7:0]  an       // enable anoda, active low (AN0=digit kanan)
);
    reg [REFRESH_BITS+2:0] cnt = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cnt <= 0;
        else        cnt <= cnt + 1'b1;
    end

    wire [2:0] sel = cnt[REFRESH_BITS+2:REFRESH_BITS]; // digit aktif 0..7

    reg [3:0] nib;
    always @(*) begin
        case (sel)
            3'd0: nib = value[3:0];   3'd1: nib = value[7:4];
            3'd2: nib = value[11:8];  3'd3: nib = value[15:12];
            3'd4: nib = value[19:16]; 3'd5: nib = value[23:20];
            3'd6: nib = value[27:24]; 3'd7: nib = value[31:28];
        endcase
    end

    reg [6:0] font;  // active-high: bit0=a ... bit6=g
    always @(*) begin
        case (nib)
            4'h0: font = 7'h3F; 4'h1: font = 7'h06; 4'h2: font = 7'h5B; 4'h3: font = 7'h4F;
            4'h4: font = 7'h66; 4'h5: font = 7'h6D; 4'h6: font = 7'h7D; 4'h7: font = 7'h07;
            4'h8: font = 7'h7F; 4'h9: font = 7'h6F; 4'hA: font = 7'h77; 4'hB: font = 7'h7C;
            4'hC: font = 7'h39; 4'hD: font = 7'h5E; 4'hE: font = 7'h79; 4'hF: font = 7'h71;
            default: font = 7'h00;
        endcase
    end

    always @(*) begin
        seg = ~font;             // segmen active-low
        an  = ~(8'b1 << sel);    // hanya digit terpilih yang aktif (active-low)
    end
    assign dp = 1'b1;            // DP mati
endmodule