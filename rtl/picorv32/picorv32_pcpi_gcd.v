module picorv32_pcpi_gcd (
    input             clk,
    input             resetn,

    // PicoRV32 PCPI Interface
    input             pcpi_valid,
    input      [31:0] pcpi_insn,
    input      [31:0] pcpi_rs1,
    input      [31:0] pcpi_rs2,
    output reg        pcpi_wr,
    output reg [31:0] pcpi_rd,
    output reg        pcpi_wait,
    output reg        pcpi_ready
);

    // -------------------------------------------------------------------------
    // 1. Opcode Definition (Custom-1)
    // -------------------------------------------------------------------------
    // We use "Custom-1" (Opcode: 0101011 -> 0x2B) to distinguish from your BitRev (0x0B).
    // Instruction Format: .insn r 0x2B, 0, 0, rd, rs1, rs2
    wire is_gcd_instr = (pcpi_insn[6:0] == 7'b0101011) && 
                        (pcpi_insn[14:12] == 3'b000) && 
                        (pcpi_insn[31:25] == 7'b0000000);

    // -------------------------------------------------------------------------
    // 2. State Machine Definition
    // -------------------------------------------------------------------------
    localparam STATE_IDLE = 1'b0;
    localparam STATE_BUSY = 1'b1;

    reg state;
    reg [31:0] r_a; // Register to hold Input A
    reg [31:0] r_b; // Register to hold Input B

    // -------------------------------------------------------------------------
    // 3. Sequential Logic (The Calculation)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= STATE_IDLE;
            pcpi_ready <= 0;
            pcpi_wr    <= 0;
            pcpi_rd    <= 0;
            pcpi_wait  <= 0;
            r_a        <= 0;
            r_b        <= 0;
        end else begin
            // Default: Clear "Done" signals after 1 cycle pulse
            pcpi_ready <= 0;
            pcpi_wr    <= 0;

            case (state)
                // --- STATE: IDLE (Waiting for Instruction) ---
                STATE_IDLE: begin
                    if (pcpi_valid && is_gcd_instr) begin
                        // 1. Capture Inputs
                        r_a <= pcpi_rs1;
                        r_b <= pcpi_rs2;
                        
                        // 2. Start Calculation
                        state <= STATE_BUSY;
                        
                        // 3. Tell CPU to WAIT (Stall Pipeline)
                        pcpi_wait <= 1; 
                    end else begin
                        pcpi_wait <= 0;
                    end
                end

                // --- STATE: BUSY (Subtracting Loop) ---
                STATE_BUSY: begin
                    if (r_b == 0) begin
                        // --- ALGORITHM FINISHED ---
                        state <= STATE_IDLE;
                        
                        // Output Result (GCD is in r_a)
                        pcpi_rd <= r_a;
                        
                        // Handshake: "Here is the data, I am done."
                        pcpi_ready <= 1;
                        pcpi_wr    <= 1;
                        
                        // Release the CPU (Stop Waiting)
                        pcpi_wait  <= 0; 
                        
                    end else begin
                        // --- CALCULATING (Euclidean Step) ---
                        // Keep pcpi_wait HIGH so CPU doesn't move
                        pcpi_wait <= 1; 
                        
                        // if (r_a > r_b)
                        //     r_a <= r_a - r_b;
                        // else
                        //     r_b <= r_b - r_a;

                        r_a <= r_b;
                        r_b <= r_a % r_b;
                    end
                end
            endcase
        end
    end

endmodule