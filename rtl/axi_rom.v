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
    reg [31:0] mem [0:2000]; 
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
    mem[31] = 32'h10001117;
    mem[32] = 32'hf8410113;
    mem[33] = 32'h008000ef;
    mem[34] = 32'h050000ef;
    mem[35] = 32'h100007b7;
    mem[36] = 32'h100006b7;
    mem[37] = 32'h00078793;
    mem[38] = 32'h48800713;
    mem[39] = 32'h00068693;
    mem[40] = 32'h00d7ec63;
    mem[41] = 32'h100007b7;
    mem[42] = 32'h00078793;
    mem[43] = 32'h48800713;
    mem[44] = 32'h00e7ee63;
    mem[45] = 32'h00008067;
    mem[46] = 32'h00074603;
    mem[47] = 32'h00170713;
    mem[48] = 32'h00178793;
    mem[49] = 32'hfec78fa3;
    mem[50] = 32'hfd9ff06f;
    mem[51] = 32'h00178793;
    mem[52] = 32'hfe078fa3;
    mem[53] = 32'hfddff06f;
    mem[54] = 32'h000307b7;
    mem[55] = 32'h0387a683;
    mem[56] = 32'hf1170737;
    mem[57] = 32'h00170713;
    mem[58] = 32'h03878793;
    mem[59] = 32'h02e68063;
    mem[60] = 32'h00020737;
    mem[61] = 32'hdead06b7;
    mem[62] = 32'h00d72023;
    mem[63] = 32'h0007a703;
    mem[64] = 32'h000207b7;
    mem[65] = 32'h00e7a423;
    mem[66] = 32'h0000006f;
    mem[67] = 32'h3d300793;
    mem[68] = 32'h00030737;
    mem[69] = 32'h00f72823;
    mem[70] = 32'h000306b7;
    mem[71] = 32'h7a600613;
    mem[72] = 32'h00c6aa23;
    mem[73] = 32'h00f6ac23;
    mem[74] = 32'hffffb7b7;
    mem[75] = 32'h8a278793;
    mem[76] = 32'h00002637;
    mem[77] = 32'h00f6ae23;
    mem[78] = 32'h000305b7;
    mem[79] = 32'he9160613;
    mem[80] = 32'h02c5a023;
    mem[81] = 32'h10000613;
    mem[82] = 32'h02c5a223;
    mem[83] = 32'h20000513;
    mem[84] = 32'h02a5a423;
    mem[85] = 32'h02c5a623;
    mem[86] = 32'hffffa637;
    mem[87] = 32'h8d960613;
    mem[88] = 32'h02c5a823;
    mem[89] = 32'h00003637;
    mem[90] = 32'hfa660613;
    mem[91] = 32'h02c5aa23;
    mem[92] = 32'h00058613;
    mem[93] = 32'h00100593;
    mem[94] = 32'h00b62023;
    mem[95] = 32'h01070713;
    mem[96] = 32'h00072703;
    mem[97] = 32'h01c68693;
    mem[98] = 32'h0006a683;
    mem[99] = 32'hc2d70713;
    mem[100] = 32'h00e03733;
    mem[101] = 32'h00f68463;
    mem[102] = 32'h00276713;
    mem[103] = 32'h28400693;
    mem[104] = 32'h000305b7;
    mem[105] = 32'h00030637;
    mem[106] = 32'h00668513;
    mem[107] = 32'h00068793;
    mem[108] = 32'h00858593;
    mem[109] = 32'h00c60613;
    mem[110] = 32'h00079803;
    mem[111] = 32'h00278793;
    mem[112] = 32'h0105a023;
    mem[113] = 32'h00062803;
    mem[114] = 32'hfea798e3;
    mem[115] = 32'h00030537;
    mem[116] = 32'h000305b7;
    mem[117] = 32'h100007b7;
    mem[118] = 32'h00000613;
    mem[119] = 32'h00850513;
    mem[120] = 32'h00c58593;
    mem[121] = 32'h00078793;
    mem[122] = 32'h1fa00813;
    mem[123] = 32'h00669883;
    mem[124] = 32'h00268693;
    mem[125] = 32'h01152023;
    mem[126] = 32'h0005a303;
    mem[127] = 32'h00c788b3;
    mem[128] = 32'h00260613;
    mem[129] = 32'h00689023;
    mem[130] = 32'hff0612e3;
    mem[131] = 32'h000305b7;
    mem[132] = 32'h00030637;
    mem[133] = 32'h00678513;
    mem[134] = 32'h00078693;
    mem[135] = 32'h00858593;
    mem[136] = 32'h00c60613;
    mem[137] = 32'h0005a023;
    mem[138] = 32'h00062803;
    mem[139] = 32'h00268693;
    mem[140] = 32'h1f069c23;
    mem[141] = 32'hfed518e3;
    mem[142] = 32'h000206b7;
    mem[143] = 32'h10000613;
    mem[144] = 32'h00c6a223;
    mem[145] = 32'h00e6a423;
    mem[146] = 32'h21068613;
    mem[147] = 32'h01068713;
    mem[148] = 32'h0027d683;
    mem[149] = 32'h0007d583;
    mem[150] = 32'h00470713;
    mem[151] = 32'h01069693;
    mem[152] = 32'h00b6e6b3;
    mem[153] = 32'hfed72e23;
    mem[154] = 32'h00478793;
    mem[155] = 32'hfec712e3;
    mem[156] = 32'h000207b7;
    mem[157] = 32'hf1170737;
    mem[158] = 32'h00e7a023;
    mem[159] = 32'h00100073;
    mem[160] = 32'h0000006f;
    mem[161] = 32'h1b200000;
    mem[162] = 32'h0641fa11;
    mem[163] = 32'h0caf2a66;
    mem[164] = 32'h2d050693;
    mem[165] = 32'hfe55164a;
    mem[166] = 32'h15372125;
    mem[167] = 32'h0acfefce;
    mem[168] = 32'he1610ce8;
    mem[169] = 32'h03d5f239;
    mem[170] = 32'he03eda8b;
    mem[171] = 32'he03e0000;
    mem[172] = 32'h03d5da8b;
    mem[173] = 32'he161f239;
    mem[174] = 32'h0acf0ce8;
    mem[175] = 32'h1537efce;
    mem[176] = 32'hfe552125;
    mem[177] = 32'h2d05164a;
    mem[178] = 32'h0caf0693;
    mem[179] = 32'h06412a66;
    mem[180] = 32'h1b20fa11;
    mem[181] = 32'he4e00000;
    mem[182] = 32'hf9bf05ef;
    mem[183] = 32'hf351d59a;
    mem[184] = 32'hd2fbf96d;
    mem[185] = 32'h01abe9b6;
    mem[186] = 32'heac9dedb;
    mem[187] = 32'hf5311032;
    mem[188] = 32'h1e9ff318;
    mem[189] = 32'hfc2b0dc7;
    mem[190] = 32'h1fc22575;
    mem[191] = 32'h1fc20000;
    mem[192] = 32'hfc2b2575;
    mem[193] = 32'h1e9f0dc7;
    mem[194] = 32'hf531f318;
    mem[195] = 32'heac91032;
    mem[196] = 32'h01abdedb;
    mem[197] = 32'hd2fbe9b6;
    mem[198] = 32'hf351f96d;
    mem[199] = 32'hf9bfd59a;
    mem[200] = 32'he4e005ef;
    mem[201] = 32'h1b200000;
    mem[202] = 32'h0641fa11;
    mem[203] = 32'h0caf2a66;
    mem[204] = 32'h2d050693;
    mem[205] = 32'hfe55164a;
    mem[206] = 32'h15372125;
    mem[207] = 32'h0acfefce;
    mem[208] = 32'he1610ce8;
    mem[209] = 32'h03d5f239;
    mem[210] = 32'he03eda8b;
    mem[211] = 32'he03e0000;
    mem[212] = 32'h03d5da8b;
    mem[213] = 32'he161f239;
    mem[214] = 32'h0acf0ce8;
    mem[215] = 32'h1537efce;
    mem[216] = 32'hfe552125;
    mem[217] = 32'h2d05164a;
    mem[218] = 32'h0caf0693;
    mem[219] = 32'h06412a66;
    mem[220] = 32'h1b20fa11;
    mem[221] = 32'he4e00000;
    mem[222] = 32'hf9bf05ef;
    mem[223] = 32'hf351d59a;
    mem[224] = 32'hd2fbf96d;
    mem[225] = 32'h01abe9b6;
    mem[226] = 32'heac9dedb;
    mem[227] = 32'hf5311032;
    mem[228] = 32'h1e9ff318;
    mem[229] = 32'hfc2b0dc7;
    mem[230] = 32'h1fc22575;
    mem[231] = 32'h1fc20000;
    mem[232] = 32'hfc2b2575;
    mem[233] = 32'h1e9f0dc7;
    mem[234] = 32'hf531f318;
    mem[235] = 32'heac91032;
    mem[236] = 32'h01abdedb;
    mem[237] = 32'hd2fbe9b6;
    mem[238] = 32'hf351f96d;
    mem[239] = 32'hf9bfd59a;
    mem[240] = 32'he4e005ef;
    mem[241] = 32'h1b200000;
    mem[242] = 32'h0641fa11;
    mem[243] = 32'h0caf2a66;
    mem[244] = 32'h2d050693;
    mem[245] = 32'hfe55164a;
    mem[246] = 32'h15372125;
    mem[247] = 32'h0acfefce;
    mem[248] = 32'he1610ce8;
    mem[249] = 32'h03d5f239;
    mem[250] = 32'he03eda8b;
    mem[251] = 32'he03e0000;
    mem[252] = 32'h03d5da8b;
    mem[253] = 32'he161f239;
    mem[254] = 32'h0acf0ce8;
    mem[255] = 32'h1537efce;
    mem[256] = 32'hfe552125;
    mem[257] = 32'h2d05164a;
    mem[258] = 32'h0caf0693;
    mem[259] = 32'h06412a66;
    mem[260] = 32'h1b20fa11;
    mem[261] = 32'he4e00000;
    mem[262] = 32'hf9bf05ef;
    mem[263] = 32'hf351d59a;
    mem[264] = 32'hd2fbf96d;
    mem[265] = 32'h01abe9b6;
    mem[266] = 32'heac9dedb;
    mem[267] = 32'hf5311032;
    mem[268] = 32'h1e9ff318;
    mem[269] = 32'hfc2b0dc7;
    mem[270] = 32'h1fc22575;
    mem[271] = 32'h1fc20000;
    mem[272] = 32'hfc2b2575;
    mem[273] = 32'h1e9f0dc7;
    mem[274] = 32'hf531f318;
    mem[275] = 32'heac91032;
    mem[276] = 32'h01abdedb;
    mem[277] = 32'hd2fbe9b6;
    mem[278] = 32'hf351f96d;
    mem[279] = 32'hf9bfd59a;
    mem[280] = 32'he4e005ef;
    mem[281] = 32'h1b200000;
    mem[282] = 32'h0641fa11;
    mem[283] = 32'h0caf2a66;
    mem[284] = 32'h2d050693;
    mem[285] = 32'hfe55164a;
    mem[286] = 32'h15372125;
    mem[287] = 32'h0acfefce;
    mem[288] = 32'he1610ce8;
    mem[289] = 32'h00000000;
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
