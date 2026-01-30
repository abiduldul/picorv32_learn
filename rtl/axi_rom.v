module axi_rom (
    input         clk,
    input         rst_n,

    // AXI4-Lite Interface (Read-Only)
    input         axi_arvalid,
    output        axi_arready,
    input  [31:0] axi_araddr,
    output        axi_rvalid,
    input         axi_rready,
    output [31:0] axi_rdata
);

    // ===============================
    // ROM memory
    // ===============================
    reg [31:0] mem [0:106]; 
    //reg [31:0] mem [0:106]; // ukuran teST biar simulasi tidak terlalu lama

    // ===============================
    // ROM initialization
    // ===============================
initial begin
    mem[0] = 32'h00000093;
    mem[1] = 32'h00000113;
    mem[2] = 32'h00000193;
    mem[3] = 32'h00000213;
    mem[4] = 32'h00000293;
    mem[5] = 32'h00000313;
    mem[6] = 32'h00000393;
    mem[7] = 32'h00000413;
    mem[8] = 32'h00000493;
    mem[9] = 32'h00000513;
    mem[10] = 32'h00000593;
    mem[11] = 32'h00000613;
    mem[12] = 32'h00000693;
    mem[13] = 32'h00000713;
    mem[14] = 32'h00000793;
    mem[15] = 32'h00000813;
    mem[16] = 32'h00000893;
    mem[17] = 32'h00000913;
    mem[18] = 32'h00000993;
    mem[19] = 32'h00000a13;
    mem[20] = 32'h00000a93;
    mem[21] = 32'h00000b13;
    mem[22] = 32'h00000b93;
    mem[23] = 32'h00000c13;
    mem[24] = 32'h00000c93;
    mem[25] = 32'h00000d13;
    mem[26] = 32'h00000d93;
    mem[27] = 32'h00000e13;
    mem[28] = 32'h00000e93;
    mem[29] = 32'h00000f13;
    mem[30] = 32'h00000f93;
    mem[31] = 32'h10002117;
    mem[32] = 32'hf8410113;
    mem[33] = 32'h008000ef;
    mem[34] = 32'h09c000ef;
    mem[35] = 32'hfe010113;
    mem[36] = 32'h00112e23;
    mem[37] = 32'h00812c23;
    mem[38] = 32'h02010413;
    mem[39] = 32'h1a000793;
    mem[40] = 32'hfef42623;
    mem[41] = 32'h100007b7;
    mem[42] = 32'h00078793;
    mem[43] = 32'hfef42423;
    mem[44] = 32'h0240006f;
    mem[45] = 32'hfec42703;
    mem[46] = 32'h00170793;
    mem[47] = 32'hfef42623;
    mem[48] = 32'hfe842783;
    mem[49] = 32'h00178693;
    mem[50] = 32'hfed42423;
    mem[51] = 32'h00074703;
    mem[52] = 32'h00e78023;
    mem[53] = 32'hfe842703;
    mem[54] = 32'h100007b7;
    mem[55] = 32'h00078793;
    mem[56] = 32'hfcf76ae3;
    mem[57] = 32'h100007b7;
    mem[58] = 32'h00078793;
    mem[59] = 32'hfef42423;
    mem[60] = 32'h0140006f;
    mem[61] = 32'hfe842783;
    mem[62] = 32'h00178713;
    mem[63] = 32'hfee42423;
    mem[64] = 32'h00078023;
    mem[65] = 32'hfe842703;
    mem[66] = 32'h1a000793;
    mem[67] = 32'hfef764e3;
    mem[68] = 32'h00000013;
    mem[69] = 32'h01c12083;
    mem[70] = 32'h01812403;
    mem[71] = 32'h02010113;
    mem[72] = 32'h00008067;
    mem[73] = 32'hfe010113;
    mem[74] = 32'h00112e23;
    mem[75] = 32'h00812c23;
    mem[76] = 32'h02010413;
    mem[77] = 32'h000207b7;
    mem[78] = 32'h00010737;
    mem[79] = 32'hfff70713;
    mem[80] = 32'h00e7a023;
    mem[81] = 32'hfe042623;
    mem[82] = 32'h0140006f;
    mem[83] = 32'h00000013;
    mem[84] = 32'hfec42783;
    mem[85] = 32'h00178793;
    mem[86] = 32'hfef42623;
    mem[87] = 32'hfec42703;
    mem[88] = 32'h0007a7b7;
    mem[89] = 32'h11f78793;
    mem[90] = 32'hfee7f2e3;
    mem[91] = 32'h000207b7;
    mem[92] = 32'h0007a023;
    mem[93] = 32'hfe042423;
    mem[94] = 32'h0140006f;
    mem[95] = 32'h00000013;
    mem[96] = 32'hfe842783;
    mem[97] = 32'h00178793;
    mem[98] = 32'hfef42423;
    mem[99] = 32'hfe842703;
    mem[100] = 32'h0007a7b7;
    mem[101] = 32'h11f78793;
    mem[102] = 32'hfee7f2e3;
    mem[103] = 32'hf99ff06f;
end

    // ===============================
    // AXI Read logic
    // ===============================
    reg [31:0] read_addr;
    reg        read_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            read_en <= 1'b0;
        end
        else if (axi_arvalid && axi_arready) begin
            read_addr <= axi_araddr[13:2]; // word aligned
            read_en   <= 1'b1;
        end
        else if (axi_rvalid && axi_rready) begin
            read_en <= 1'b0;
        end
    end

    assign axi_arready = ~read_en;
    assign axi_rvalid  = read_en;
    assign axi_rdata   = mem[read_addr];

endmodule
