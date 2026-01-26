module picorv32_soc (
    input  wire clk,
    input  wire rst_n,
    output wire trap,
    // input  [15:0]                   sw,
    output                    LED
);
    
    // always @(posedge clk) begin
    //     if (clk_divider >= 100_000_000 / 2 - 1) begin
    //         clk_divider <= 0;
    //         clk_slow <= ~clk_slow;
    //     end else begin
    //         clk_divider <= clk_divider + 1;
    //     end
    // end
    
    
    /* master 0 signals */
    wire                m0_AWVALID, m0_AWREADY;
    wire    [31:0]      m0_AWADDR;
    
    wire                m0_WVALID, m0_WREADY;
    wire    [3:0]       m0_WSTRB;
    wire    [31:0]      m0_WDATA;
    
    wire                m0_BREADY, m0_BVALID;
    wire    [1:0]       m0_BRESP;

    wire                m0_ARVALID, m0_ARREADY;
    wire    [31:0]      m0_ARADDR;
    
    wire                m0_RREADY, m0_RVALID;
    wire    [1:0]       m0_RRESP;
    wire    [31:0]      m0_RDATA;
    
    
    /* slave 0 signals */
    wire                s0_AWVALID, s0_AWREADY;
    wire    [31:0]      s0_AWADDR;
    
    wire                s0_WVALID, s0_WREADY;
    wire    [3:0]       s0_WSTRB;
    wire    [31:0]      s0_WDATA;
    
    wire                s0_BREADY, s0_BVALID;
    wire    [1:0]       s0_BRESP;
    
    wire                s0_ARVALID, s0_ARREADY;
    wire    [31:0]      s0_ARADDR;
    
    wire                s0_RREADY, s0_RVALID;
    wire    [1:0]       s0_RRESP;
    wire    [31:0]      s0_RDATA;
    
    
    /* slave 1 signals */
    wire                s1_AWVALID, s1_AWREADY;
    wire    [31:0]      s1_AWADDR;
    
    wire                s1_WVALID, s1_WREADY;
    wire    [3:0]       s1_WSTRB;
    wire    [31:0]      s1_WDATA;
    
    wire                s1_BREADY, s1_BVALID;
    wire    [1:0]       s1_BRESP;
    
    wire                s1_ARVALID, s1_ARREADY;
    wire    [31:0]      s1_ARADDR;
    
    wire                s1_RREADY, s1_RVALID;
    wire    [1:0]       s1_RRESP;
    wire    [31:0]      s1_RDATA;

    /* slave 2 signals */
    wire                s2_AWVALID, s2_AWREADY;
    wire    [31:0]      s2_AWADDR;

    wire                s2_WVALID, s2_WREADY;
    wire    [3:0]       s2_WSTRB;
    wire    [31:0]      s2_WDATA;

    wire                s2_BREADY, s2_BVALID;
    wire    [1:0]       s2_BRESP;

    wire                s2_ARVALID, s2_ARREADY;
    wire    [31:0]      s2_ARADDR;

    wire                s2_RREADY, s2_RVALID;
    wire    [1:0]       s2_RRESP;
    wire    [31:0]      s2_RDATA;

    /* master */
    picorv32_axi #(
        .STACKADDR(32'h10003f00),
        .ENABLE_FAST_MUL(1'b0),
        .ENABLE_MUL(1'b1),
        .ENABLE_DIV(1'b1),
        .ENABLE_BITREV(1'b0),
        .ENABLE_GCD(1'b0)
    ) cpu (
        // .clk          (clk_slow),
        .clk          (clk),
        .resetn       (rst_n),
        .trap           (trap),
        .mem_axi_awvalid (m0_AWVALID), .mem_axi_awready (m0_AWREADY), .mem_axi_awaddr (m0_AWADDR),
        .mem_axi_wvalid (m0_WVALID), .mem_axi_wready (m0_WREADY), .mem_axi_wdata (m0_WDATA), .mem_axi_wstrb (m0_WSTRB),
        .mem_axi_bvalid (m0_BVALID), .mem_axi_bready (m0_BREADY),

        .mem_axi_arvalid (m0_ARVALID), .mem_axi_arready (m0_ARREADY), .mem_axi_araddr (m0_ARADDR),
        .mem_axi_rvalid (m0_RVALID), .mem_axi_rready (m0_RREADY), .mem_axi_rdata (m0_RDATA)
    );

    /* slave 0: ROM */
    axi_rom rom (
        // .clk          (clk_slow),
        .clk          (clk),
        .rst_n        (rst_n),

        .axi_arvalid (s0_ARVALID), .axi_arready (s0_ARREADY), .axi_araddr (s0_ARADDR),
        .axi_rvalid (s0_RVALID), .axi_rready (s0_RREADY), .axi_rdata (s0_RDATA)
    );

    /* slave 1: RAM */
    axi_ram ram (
        // .clk          (clk_slow),
        .clk          (clk),
        .rst_n        (rst_n),

        .axi_awvalid (s1_AWVALID), .axi_awready (s1_AWREADY), .axi_awaddr (s1_AWADDR),
        .axi_wvalid (s1_WVALID), .axi_wready (s1_WREADY), .axi_wdata (s1_WDATA), .axi_wstrb (s1_WSTRB),
        .axi_bvalid (s1_BVALID), .axi_bready (s1_BREADY),

        .axi_arvalid (s1_ARVALID), .axi_arready (s1_ARREADY), .axi_araddr (s1_ARADDR),
        .axi_rvalid (s1_RVALID), .axi_rready (s1_RREADY), .axi_rdata (s1_RDATA)
    );
    
    /* slave 2: RAM_OUTPUT */
    axi_ram ram_output (
        // .clk          (clk_slow),
        .clk          (clk),
        .rst_n        (rst_n),

        .axi_awvalid (s2_AWVALID), .axi_awready (s2_AWREADY), .axi_awaddr (s2_AWADDR),
        .axi_wvalid (s2_WVALID), .axi_wready (s2_WREADY), .axi_wdata (s2_WDATA), .axi_wstrb (s2_WSTRB),
        .axi_bvalid (s2_BVALID), .axi_bready (s2_BREADY),

        .axi_arvalid (s2_ARVALID), .axi_arready (s2_ARREADY), .axi_araddr (s2_ARADDR),
        .axi_rvalid (s2_RVALID), .axi_rready (s2_RREADY), .axi_rdata (s2_RDATA)
    );

    // /* slave 2: GPIO */
    // axi4_lite_gpio_wrapper #(
    //     .ADDR_WIDTH(32), .DATA_WIDTH(32)
    // ) gpio (
    //     // .iCLK(clk_slow), .iRST(rst_n),
    //     .iCLK(clk), .iRST(rst_n),
        
    //     /* write */
    //     .s_AWVALID(s2_AWVALID), .s_AWPROT(3'b0), .s_AWADDR(s2_AWADDR), .s_AWREADY(s2_AWREADY),
    //     .s_WVALID(s2_WVALID), .s_WDATA(s2_WDATA), .s_WSTRB(s2_WSTRB), .s_WREADY(s2_WREADY),
    //     .s_BREADY(s2_BREADY), .s_BVALID(s2_BVALID), .s_BRESP(s2_BRESP),

    //     /* read */
    //     .s_ARVALID(s2_ARVALID), .s_ARPROT(3'b0), .s_ARADDR(s2_ARADDR), .s_ARREADY(s2_ARREADY),
    //     .s_RREADY(s2_RREADY), .s_RVALID(s2_RVALID), .s_RRESP(s2_RRESP), .s_RDATA(s2_RDATA),
    //     //.iSW(sw),
    //     .oLED(LED)
    // );

    axi4_lite_interconnect_m1s3 #(
        .LOW_ADDR0(32'h0000_0000), .HIGH_ADDR0(32'h0000_FFFF),
        .LOW_ADDR1(32'h1000_0000), .HIGH_ADDR1(32'h1000_FFFF),
        .LOW_ADDR2(32'h0002_0000), .HIGH_ADDR2(32'h0002_FFFF)
    ) interconnect (
        .iCLK(clk), .iRST(rst_n),
        
        /* master 0 signals */
        .m0_AWVALID(m0_AWVALID), .m0_AWADDR(m0_AWADDR), .m0_AWREADY(m0_AWREADY),
        .m0_WVALID(m0_WVALID), .m0_WSTRB(m0_WSTRB), .m0_WDATA(m0_WDATA), .m0_WREADY(m0_WREADY),
        .m0_BREADY(m0_BREADY), .m0_BVALID(m0_BVALID), .m0_BRESP(m0_BRESP),
        .m0_ARVALID(m0_ARVALID), .m0_ARADDR(m0_ARADDR), .m0_ARREADY(m0_ARREADY),
        .m0_RREADY(m0_RREADY), .m0_RVALID(m0_RVALID), .m0_RRESP(m0_RRESP), .m0_RDATA(m0_RDATA),
        
        /* slave 0 signals */
        .s0_AWREADY(s0_AWREADY), .s0_AWVALID(s0_AWVALID), .s0_AWADDR(s0_AWADDR),
        .s0_WREADY(s0_WREADY), .s0_WVALID(s0_WVALID), .s0_WSTRB(s0_WSTRB), .s0_WDATA(s0_WDATA),
        .s0_BVALID(s0_BVALID), .s0_BRESP(s0_BRESP), .s0_BREADY(s0_BREADY),
        .s0_ARREADY(s0_ARREADY), .s0_ARVALID(s0_ARVALID), .s0_ARADDR(s0_ARADDR), 
        .s0_RVALID(s0_RVALID), .s0_RRESP(s0_RRESP), .s0_RDATA(s0_RDATA), .s0_RREADY(s0_RREADY),

        /* slave 1 signals */
        .s1_AWREADY(s1_AWREADY), .s1_AWVALID(s1_AWVALID), .s1_AWADDR(s1_AWADDR),
        .s1_WREADY(s1_WREADY), .s1_WVALID(s1_WVALID), .s1_WSTRB(s1_WSTRB), .s1_WDATA(s1_WDATA),
        .s1_BVALID(s1_BVALID), .s1_BRESP(s1_BRESP), .s1_BREADY(s1_BREADY),
        .s1_ARREADY(s1_ARREADY), .s1_ARVALID(s1_ARVALID), .s1_ARADDR(s1_ARADDR), 
        .s1_RVALID(s1_RVALID), .s1_RRESP(s1_RRESP), .s1_RDATA(s1_RDATA), .s1_RREADY(s1_RREADY),

        /* slave 2 signals */
        .s2_AWREADY(s2_AWREADY), .s2_AWVALID(s2_AWVALID), .s2_AWADDR(s2_AWADDR),
        .s2_WREADY(s2_WREADY), .s2_WVALID(s2_WVALID), .s2_WSTRB(s2_WSTRB), .s2_WDATA(s2_WDATA),
        .s2_BVALID(s2_BVALID), .s2_BRESP(s2_BRESP), .s2_BREADY(s2_BREADY),
        .s2_ARREADY(s2_ARREADY), .s2_ARVALID(s2_ARVALID), .s2_ARADDR(s2_ARADDR), 
        .s2_RVALID(s2_RVALID), .s2_RRESP(s2_RRESP), .s2_RDATA(s2_RDATA), .s2_RREADY(s2_RREADY)
    );
    
    // assign LED = m0_RDATA[7:0];
//    assign LED = {m0_ARREADY, m0_ARVALID, m0_RREADY, m0_RVALID};
    // assign DEL = m0_WDATA[7:0];    
//    assign DEL = {m0_AWREADY, m0_AWVALID, m0_WREADY, m0_WVALID, m0_BREADY, m0_BVALID, s1_AWREADY, s1_AWVALID};
endmodule