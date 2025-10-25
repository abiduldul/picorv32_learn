module axi4_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input                               iCLK,
    input                               iRST,
    
    /* write address channel */
    input                               s_AWVALID,
    input       [2:0]                   s_AWPROT,
    input       [ADDR_WIDTH-1:0]        s_AWADDR,
    output                              s_AWREADY,
    
    /* write data channel */
    input                               s_WVALID,
    input       [DATA_WIDTH-1:0]        s_WDATA,
    input       [(DATA_WIDTH/8)-1:0]    s_WSTRB,
    output                              s_WREADY,
    
    /* write response channel */
    input                               s_BREADY,
    output                              s_BVALID,
    output      [1:0]                   s_BRESP,
    
    /* read address channel */
    input                               s_ARVALID,
    input       [2:0]                   s_ARPROT,
    input       [ADDR_WIDTH-1:0]        s_ARADDR,
    output                              s_ARREADY,
    
    /* read data channel */
    input                               s_RREADY,
    output                              s_RVALID,
    output      [1:0]                   s_RRESP,
    output      [DATA_WIDTH-1:0]        s_RDATA,

    /* wire interface */
    input       [1:0]                   write_resp,
    output      [ADDR_WIDTH-1:0]        write_addr,
    output      [DATA_WIDTH-1:0]        write_data,
    output      [(DATA_WIDTH/8)-1:0]    write_strb,

    /* read interface */
    input       [1:0]                   read_resp,
    input       [DATA_WIDTH-1:0]        read_data,
    output      [ADDR_WIDTH-1:0]        read_addr
);

    /* finite state machine */
    localparam IDLE     = 3'b000;
    localparam WADDR    = 3'b001;
    localparam WDATA    = 3'b010;
    localparam WRESP    = 3'b011;
    localparam RADDR    = 3'b100;
    localparam RDATA    = 3'b101;

    /* state */
    reg         read_start, write_start;
    reg [2:0]   state, next_state;

    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            state           <= IDLE;
        end else begin
            state           <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = (s_AWVALID) ? WADDR : ((s_ARVALID) ? RADDR : IDLE);
            WADDR: if (s_AWVALID && s_AWREADY)  next_state  = WDATA;
            WDATA: if (s_WVALID  && s_WREADY)   next_state  = WRESP;
            WRESP: if (s_BVALID  && s_BREADY)   next_state  = IDLE;
            RADDR: if (s_ARVALID && s_ARREADY)  next_state  = RDATA;
            RDATA: if (s_RVALID  && s_RREADY)   next_state  = IDLE;
        endcase
    end    

    /* write request */
    assign s_AWREADY    = (state == WADDR) ? 1'b1           : 1'b0;
    assign write_addr   = (state == WADDR) ? s_AWADDR       : {ADDR_WIDTH{1'b0}};

    /* write data */
    assign s_WREADY     = (state == WDATA) ? 1'b1           : 1'b0;
    assign write_data   = (state == WDATA) ? s_WDATA        : {DATA_WIDTH{1'b0}};
    assign write_strb   = (state == WDATA) ? s_WSTRB        : {(DATA_WIDTH/8){1'b0}};

    /* write response */
    assign s_BVALID     = (state == WRESP) ? 1'b1           : 1'b0;
    assign s_BRESP      = (state == WRESP) ? write_resp     : 2'b00; // OKAY response

    /* read request */
    assign s_ARREADY    = (state == RADDR) ? 1'b1           : 1'b0;
    assign read_addr    = (state == RADDR) ? s_ARADDR       : {ADDR_WIDTH{1'b0}};

    /* read data */
    assign s_RVALID     = (state == RDATA) ? 1'b1           : 1'b0;
    assign s_RDATA      = (state == RDATA) ? read_data      : {DATA_WIDTH{1'b0}};
    assign s_RRESP      = (state == RDATA) ? read_resp      : 2'b00; // OKAY response

endmodule