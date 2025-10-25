module axi_ram (
    input         clk,
    input         rst_n,
    // AXI4-Lite Interface (Read/Write)
    input         axi_awvalid,
    output        axi_awready,
    input  [31:0] axi_awaddr,
    input         axi_wvalid,
    output        axi_wready,
    input  [31:0] axi_wdata,
    input  [3:0]  axi_wstrb,
    output        axi_bvalid,
    input         axi_bready,
    input         axi_arvalid,
    output        axi_arready,
    input  [31:0] axi_araddr,
    output        axi_rvalid,
    input         axi_rready,
    output [31:0] axi_rdata
);

    reg [31:0] mem [0:256];
    integer i;

    // initial begin
    //     mem[0] = 32'h00002710;
    //     mem[1] = 32'h00004e20;
    //     mem[2] = 32'h0000c350;
    //     mem[3] = 32'h00004e20;
    // end


    reg [1:0] state;
    reg [31:0] wr_addr, rd_addr;
    reg [3:0] wr_strb;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 0;
            for (i = 0; i < 32; i = i + 1) mem[i] <= 0;
        end else begin
            case (state)
                0: begin  // Idle
                    if (axi_awvalid && axi_wvalid) begin  // Write request
                        wr_addr <= axi_awaddr[13:2];
                        wr_strb <= axi_wstrb;
                        if (axi_wstrb[0]) mem[axi_awaddr[13:2]][7:0]   <= axi_wdata[7:0];
                        if (axi_wstrb[1]) mem[axi_awaddr[13:2]][15:8]  <= axi_wdata[15:8];
                        if (axi_wstrb[2]) mem[axi_awaddr[13:2]][23:16] <= axi_wdata[23:16];
                        if (axi_wstrb[3]) mem[axi_awaddr[13:2]][31:24] <= axi_wdata[31:24];
                        state <= 1;
                    end else if (axi_arvalid) begin  // Read request
                        rd_addr <= axi_araddr[13:2];
                        state <= 2;
                    end
                end
                1: begin  // Write response
                    if (axi_bready) state <= 0;
                end
                2: begin  // Read response
                    if (axi_rready) state <= 0;
                end
            endcase
        end
    end

    assign axi_awready = (state == 0);
    assign axi_wready  = (state == 0);
    assign axi_bvalid  = (state == 1);
    assign axi_arready = (state == 0);
    assign axi_rvalid  = (state == 2);
    assign axi_rdata   = mem[rd_addr];
    
endmodule