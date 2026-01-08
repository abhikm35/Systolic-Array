// Controller for the systolic array accelerator
// - Reads instruction stream (a, b, c, ..., 0) from instruction memory
// - Drives read addresses into A and B memories
// - Streams data into the systolic array
// - Writes results into O memory
// - Raises ap_done when all MMMs are finished

module controller #(
    parameter int DATA_W   = 16,
    parameter int INSTR_W  = 16,
    parameter int ADDR_A_W = 11,
    parameter int ADDR_B_W = 11,
    parameter int ADDR_O_W = 11,
    parameter int ADDR_I_W = 6
)(
    // Global control
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    ap_start,
    output logic                    ap_done,

    // Instruction memory interface (read-only from controller side)
    output logic [ADDR_I_W-1:0]     instr_addr,
    input  logic [INSTR_W-1:0]      instr_dout,

    // Data memory A read interface
    output logic [ADDR_A_W-1:0]     addrA_r,
    input  logic [DATA_W-1:0]       dataA_r,

    // Data memory B read interface
    output logic [ADDR_B_W-1:0]     addrB_r,
    input  logic [DATA_W-1:0]       dataB_r,

    // Result memory O write interface
    output logic [ADDR_O_W-1:0]     addrO_w,
    output logic [DATA_W-1:0]       dataO_w,
    output logic                    weO,

    // Interface to systolic array
    output logic                    sa_start,
    output logic                    sa_clear,
    input  logic                    sa_done,
    output logic [DATA_W-1:0]       sa_in_a,
    output logic [DATA_W-1:0]       sa_in_b,
    input  logic [DATA_W-1:0]       sa_out_data,
    input  logic                    sa_out_valid
);

    // ------------------------------------------------------------------------
    // State machine declaration
    // ------------------------------------------------------------------------

    typedef enum logic [2:0] {
        S_IDLE,
        S_FETCH_A,     // read 'a' from instruction memory
        S_FETCH_B,     // read 'b'
        S_FETCH_C,     // read 'c'
        S_LOAD,        // set up counters / addresses
        S_RUN,         // stream data through systolic array
        S_WRITE_BACK,  // write results into O memory
        S_DONE
    } state_t;

    state_t state, next_state;

    // Instruction registers (a, b, c) and instruction pointer
    logic [INSTR_W-1:0] a_reg, b_reg, c_reg;
    logic [ADDR_I_W-1:0] instr_ptr;

    // TODO: add counters for addresses into A, B, and O memories

    // ------------------------------------------------------------------------
    // Sequential state/register updates
    // ------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            instr_ptr  <= '0;
            a_reg      <= '0;
            b_reg      <= '0;
            c_reg      <= '0;
        end else begin
            state <= next_state;

            // Instruction pointer and a/b/c registers updated as we step
            // through FETCH_A/B/C.
            if (state == S_FETCH_A && next_state == S_FETCH_B) begin
                a_reg     <= instr_dout;      // latch 'a'
                instr_ptr <= instr_ptr + 1;   // move to 'b'
            end
            if (state == S_FETCH_B && next_state == S_FETCH_C) begin
                b_reg     <= instr_dout;      // latch 'b'
                instr_ptr <= instr_ptr + 1;   // move to 'c'
            end
            if (state == S_FETCH_C && next_state == S_LOAD) begin
                c_reg     <= instr_dout;      // latch 'c'
                instr_ptr <= instr_ptr + 1;   // point to next triple
            end

            // Optional: reset instruction pointer when we go back to IDLE
            if (state == S_DONE && next_state == S_IDLE) begin
                instr_ptr <= '0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Combinational next-state logic and outputs
    // ------------------------------------------------------------------------

    always_comb begin
        // Default assignments
        next_state = state;
        ap_done    = 1'b0;

        // Default memory and systolic array controls
        instr_addr = instr_ptr;
        addrA_r    = '0;
        addrB_r    = '0;
        addrO_w    = '0;
        dataO_w    = '0;
        weO        = 1'b0;
        sa_start   = 1'b0;
        sa_clear   = 1'b0;
        sa_in_a    = '0;
        sa_in_b    = '0;

        unique case (state)
            S_IDLE: begin
                if (ap_start) begin
                    // Start reading instructions from the beginning
                    next_state = S_FETCH_A;
                end
            end

            // Read first word of triple: 'a'.
            S_FETCH_A: begin
                // If first word is zero, this is the terminator -> we're done.
                if (instr_dout == '0) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_FETCH_B;
                end
            end

            // Read second word of triple: 'b'.
            S_FETCH_B: begin
                next_state = S_FETCH_C;
            end

            // Read third word of triple: 'c'.
            S_FETCH_C: begin
                next_state = S_LOAD;
            end

            S_LOAD: begin
                // TODO: initialize address counters for A, B, and O
                // and assert sa_clear if needed
                addrA_r = 0;
                addrB_r = 0;
                addrO_w = 0;
                dataO_w = 0;
                weO = 1'b0;
                sa_clear = 1'b1;
                next_state = S_RUN;
            end

            S_RUN: begin
                // TODO: drive sa_in_a / sa_in_b from dataA_r / dataB_r
                // and generate read addresses addrA_r / addrB_r
                if (sa_done) begin
                    next_state = S_WRITE_BACK;               // When systolic array is done, move to S_WRITE_BACK;
                end
            end

            S_WRITE_BACK: begin
                // TODO: iterate over outputs from systolic array
                // and write them into memO using addrO_w/dataO_w/weO
                // After all outputs written, either go back to S_FETCH
                // for next MMM or to S_DONE if finished
                next_state = S_DONE;
            end

            S_DONE: begin
                ap_done = 1'b1;
                if (!ap_start) begin
                    // Wait for ap_start to be deasserted before going idle
                    next_state = S_IDLE;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule

