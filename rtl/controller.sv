// Controller for the systolic array accelerator
// - Reads instruction stream (a, b, c, ..., 0) from instruction memory
// - Drives read addresses into A and B memories
// - Streams data into the systolic array
// - Writes results into O memory
// - Raises ap_done when all MMMs are finished

module controller #(
    parameter int N        = 4,       // systolic array size (a=b=c=N for one MMM tile)
    parameter int DATA_W   = 16,
    parameter int ACC_W    = 32,      // accumulator width from systolic array
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

    // Data memory A read interface (N addresses/data per cycle for skew feed)
    output logic [ADDR_A_W-1:0]     addrA_r [0:N-1],
    input  logic [DATA_W-1:0]       dataA_r [0:N-1],

    // Data memory B read interface (N addresses/data per cycle for skew feed)
    output logic [ADDR_B_W-1:0]     addrB_r [0:N-1],
    input  logic [DATA_W-1:0]       dataB_r [0:N-1],

    // Result memory O write interface
    output logic [ADDR_O_W-1:0]     addrO_w,
    output logic [DATA_W-1:0]       dataO_w,
    output logic                    weO,

    // Interface to systolic array (N A values on west edge, N B values on north edge)
    output logic                    sa_start,
    output logic                    sa_clear,
    input  logic                    sa_done,
    output logic [DATA_W-1:0]       sa_in_a [0:N-1],
    output logic [DATA_W-1:0]       sa_in_b [0:N-1],
    input  logic [ACC_W-1:0]        sa_out_data,
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

    // Counters for feed (S_RUN) and write-back; base address for O in current MMM
    logic [ADDR_A_W-1:0] run_cnt;
    logic [ADDR_O_W-1:0] out_cnt;
    logic [ADDR_O_W-1:0] baseO;
    localparam int N_SQ = N * N;
    localparam int FEED_CYCLES = 2 * N - 1;  // skew feed cycles for NxN systolic

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
            run_cnt    <= '0;
            out_cnt    <= '0;
            baseO      <= '0;
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

            // S_LOAD: reset run and output counters
            if (state == S_LOAD && next_state == S_RUN) begin
                run_cnt <= '0;
                out_cnt <= '0;
            end

            // S_RUN: advance run counter each cycle; advance out_cnt when we write an output
            if (state == S_RUN) begin
                run_cnt <= run_cnt + 1;
                if (sa_out_valid) begin
                    out_cnt <= out_cnt + 1;
                end
            end

            // After write-back, advance baseO for next MMM (a_reg*c_reg elements)
            if (state == S_WRITE_BACK && next_state == S_FETCH_A) begin
                baseO <= ADDR_O_W'(baseO + (a_reg * c_reg));
            end

            // Reset instruction pointer and baseO when we go back to IDLE
            if (state == S_DONE && next_state == S_IDLE) begin
                instr_ptr <= '0;
                baseO     <= '0;
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
        for (int i = 0; i < N; i++) begin
            addrA_r[i] = '0;
            addrB_r[i] = '0;
            sa_in_a[i] = '0;
            sa_in_b[i] = '0;
        end
        addrO_w    = '0;
        dataO_w    = '0;
        weO        = 1'b0;
        sa_start   = 1'b0;
        sa_clear   = 1'b0;

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
                sa_clear = 1'b1;
                sa_start = 1'b1;
                for (int i = 0; i < N; i++) begin
                    addrA_r[i] = '0;
                    addrB_r[i] = '0;
                end
                next_state = S_RUN;
            end

            S_RUN: begin
                // True NxN systolic skew: at cycle t, row r gets A[r][t-r], col c gets B[t-c][c]
                // Feed for FEED_CYCLES = 2*N-1; then zeros so drain does not accumulate garbage
                sa_start = 1'b1;
                for (int r = 0; r < N; r++) begin
                    if (run_cnt >= r && run_cnt < r + N) begin
                        addrA_r[r] = r * N + (run_cnt - r);  // A[r][t-r] row-major
                        sa_in_a[r] = dataA_r[r];
                    end else begin
                        addrA_r[r] = '0;
                        sa_in_a[r] = '0;
                    end
                end
                for (int c = 0; c < N; c++) begin
                    if (run_cnt >= c && run_cnt < c + N) begin
                        addrB_r[c] = (run_cnt - c) + c * N;  // B[t-c][c] at row+(col*N) col-major
                        sa_in_b[c] = dataB_r[c];
                    end else begin
                        addrB_r[c] = '0;
                        sa_in_b[c] = '0;
                    end
                end
                // Write each valid output to O as it drains
                if (sa_out_valid) begin
                    weO     = 1'b1;
                    addrO_w = baseO + out_cnt;
                    dataO_w = sa_out_data[DATA_W-1:0];  // truncate accumulator to data width
                end
                if (sa_done) begin
                    next_state = S_WRITE_BACK;
                end
            end

            S_WRITE_BACK: begin
                // All outputs were written during S_RUN; go fetch next (a,b,c) or finish
                next_state = S_FETCH_A;
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

