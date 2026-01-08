// Top-level systolic array accelerator
// Exposes simple memory-style ports for:
//  - Writing input matrices A and B
//  - Writing the instruction stream I
//  - Reading the output matrix O

module top #(
    // Data width for matrix elements (16-bit fixed point)
    parameter int DATA_W   = 16,
    // Instruction width (integer dimensions a, b, c, ...)
    parameter int INSTR_W  = 16,

    // Memory depths (in DATA_W words)
    parameter int DEPTH_A  = 2048,
    parameter int DEPTH_B  = 2048,
    parameter int DEPTH_O  = 2048,
    parameter int DEPTH_I  = 64,

    // Address widths (derived)
    parameter int ADDR_A_W = $clog2(DEPTH_A),
    parameter int ADDR_B_W = $clog2(DEPTH_B),
    parameter int ADDR_O_W = $clog2(DEPTH_O),
    parameter int ADDR_I_W = $clog2(DEPTH_I)
)(
    // Global control
    input  logic                    clk,
    input  logic                    rst_n,      // active-low reset
    input  logic                    ap_start,   // start processing instruction stream
    output logic                    ap_done,    // all MMM operations complete

    // Data memory A write interface (input matrix)
    // Testbench/CPU drives these to preload matrix A
    input  logic [ADDR_A_W-1:0]     addrA,
    input  logic                    enA,
    input  logic [DATA_W-1:0]       dataA,

    // Data memory B write interface (weight matrix)
    input  logic [ADDR_B_W-1:0]     addrB,
    input  logic                    enB,
    input  logic [DATA_W-1:0]       dataB,

    // Instruction memory I write interface
    input  logic [ADDR_I_W-1:0]     addrI,
    input  logic                    enI,
    input  logic [INSTR_W-1:0]      dataI,

    // Result memory O read interface
    // Testbench/CPU supplies address, core returns data
    input  logic [ADDR_O_W-1:0]     addrO,
    output logic [DATA_W-1:0]       dataO
);

    // ------------------------------------------------------------------------
    // Internal memories (simple synchronous RAMs)
    // ------------------------------------------------------------------------

    // Data memory A
    logic [DATA_W-1:0] memA [0:DEPTH_A-1];

    // Data memory B
    logic [DATA_W-1:0] memB [0:DEPTH_B-1];

    // Result memory O
    logic [DATA_W-1:0] memO [0:DEPTH_O-1];

    // Instruction memory I
    logic [INSTR_W-1:0] memI [0:DEPTH_I-1];

    // ------------------------------------------------------------------------
    // External write ports for A, B, I
    // ------------------------------------------------------------------------

    // Write into A
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // no reset behavior needed for memories
        end else if (enA) begin
            memA[addrA] <= dataA;
        end
    end

    // Write into B
    always_ff @(posedge clk) begin
        if (!rst_n) begin
        end else if (enB) begin
            memB[addrB] <= dataB;
        end
    end

    // Write into I (instruction memory)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
        end else if (enI) begin
            memI[addrI] <= dataI;
        end
    end

    // ------------------------------------------------------------------------
    // Result memory read port for O
    // ------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dataO <= '0;
        end else begin
            dataO <= memO[addrO];
        end
    end

    // ------------------------------------------------------------------------
    // Controller + systolic array instances (to be implemented)
    // ------------------------------------------------------------------------

    // TODO:
    //  - Add a controller module that:
    //      * Reads instructions from memI
    //      * Drives read addresses into memA, memB
    //      * Streams data into systolic_array
    //      * Writes results into memO
    //      * Asserts ap_done when all MMMs are finished
    //  - Add a systolic_array module that performs NxN MAC operations

endmodule