`default_nettype none
//
// axi4_lite_filter_wrapper.v
//
// Wraps filter_core in the same axi4_lite_slave shell that gpio uses.
//
// The single important trick: axi4_lite_slave asserts s_WREADY for exactly one
// clock (the WDATA state is one cycle long), so `write_req_reg` is a clean
// one-cycle pulse.  Decoded against the DATA_IN offset, that pulse becomes the
// biquad's `valid` strobe.  There is no sample-rate counter anywhere in this
// design -- the CPU write IS the sample clock.
//
// One deviation from gpio: read data is driven combinationally from the
// *registered* read address, so RDATA is correct during the cycle RVALID is
// asserted.  gpio.v registers r_DATA on r_REQ, which lands one cycle late.
//
module axi4_lite_filter_wrapper #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                             iCLK,
    input  wire                             iRST,

    /* write address channel */
    input  wire                             s_AWVALID,
    input  wire [2:0]                       s_AWPROT,
    input  wire [ADDR_WIDTH-1:0]            s_AWADDR,
    output wire                             s_AWREADY,

    /* write data channel */
    input  wire                             s_WVALID,
    input  wire [DATA_WIDTH-1:0]            s_WDATA,
    input  wire [(DATA_WIDTH/8)-1:0]        s_WSTRB,
    output wire                             s_WREADY,

    /* write response channel */
    input  wire                             s_BREADY,
    output wire                             s_BVALID,
    output wire [1:0]                       s_BRESP,

    /* read address channel */
    input  wire                             s_ARVALID,
    input  wire [2:0]                       s_ARPROT,
    input  wire [ADDR_WIDTH-1:0]            s_ARADDR,
    output wire                             s_ARREADY,

    /* read data channel */
    input  wire                             s_RREADY,
    output wire                             s_RVALID,
    output wire [1:0]                       s_RRESP,
    output wire [DATA_WIDTH-1:0]            s_RDATA
);

    localparam [1:0] OKAY = 2'b00;

    wire                            write_req, read_req;
    wire [1:0]                      write_resp, read_resp;
    wire [ADDR_WIDTH-1:0]           write_addr, read_addr;
    wire [DATA_WIDTH-1:0]           write_data, read_data;
    wire [(DATA_WIDTH/8)-1:0]       write_strb;

    reg                             write_req_reg;
    reg  [ADDR_WIDTH-1:0]           write_addr_reg, read_addr_reg;
    reg  [DATA_WIDTH-1:0]           write_data_reg;

    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) axi_slave (
        .iCLK(iCLK), .iRST(iRST),

        /* write */
        .s_AWREADY(s_AWREADY), .s_AWVALID(s_AWVALID), .s_AWPROT(s_AWPROT), .s_AWADDR(s_AWADDR),
        .s_WREADY(s_WREADY), .s_WVALID(s_WVALID), .s_WDATA(s_WDATA), .s_WSTRB(s_WSTRB),
        .s_BVALID(s_BVALID), .s_BRESP(s_BRESP), .s_BREADY(s_BREADY),

        /* read */
        .s_ARREADY(s_ARREADY), .s_ARVALID(s_ARVALID), .s_ARPROT(s_ARPROT), .s_ARADDR(s_ARADDR),
        .s_RVALID(s_RVALID), .s_RRESP(s_RRESP), .s_RDATA(s_RDATA), .s_RREADY(s_RREADY),

        /* simple interface */
        .write_addr(write_addr), .write_data(write_data), .write_strb(write_strb),
        .write_resp(write_resp),
        .read_addr(read_addr), .read_data(read_data), .read_resp(read_resp)
    );

    always @(posedge iCLK) begin
        if (!iRST) begin
            write_req_reg  <= 1'b0;
            write_addr_reg <= {ADDR_WIDTH{1'b0}};
            write_data_reg <= {DATA_WIDTH{1'b0}};
            read_addr_reg  <= {ADDR_WIDTH{1'b0}};
        end else begin
            write_req_reg <= write_req;
            if (s_AWVALID && s_AWREADY) write_addr_reg <= s_AWADDR;
            if (s_WVALID  && s_WREADY ) write_data_reg <= s_WDATA;
            if (s_ARVALID && s_ARREADY) read_addr_reg  <= s_ARADDR;
        end
    end

    assign write_req  = s_WREADY;   // high for exactly one clock per write
    assign read_req   = s_RREADY;
    assign write_resp = OKAY;       // gpio.v returns SLVERR here; that is a bug
    assign read_resp  = OKAY;

    filter_core #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) core (
        .iCLK(iCLK), .iRST(iRST),
        .w_REQ(write_req_reg), .r_REQ(read_req),
        .w_ADDR(write_addr_reg), .r_ADDR(read_addr_reg),
        .w_DATA(write_data_reg), .r_DATA(read_data)
    );

endmodule
`default_nettype wire
