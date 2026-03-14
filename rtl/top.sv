// Top-level systolic array accelerator
// Exposes simple memory-style ports for:
//  - Writing input matrices A and B
//  - Writing the instruction stream I
//  - Reading the output matrix O

module top #(
    // Systolic array size (NxN PEs)
    parameter int N        = 4,
    // Data width for matrix elements (16-bit fixed point)
    parameter int DATA_W   = 16,
    // Accumulator width in PEs
    parameter int ACC_W    = 32,
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
    // Result memory read port for O (external)
    // ------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dataO <= '0;
        end else begin
            dataO <= memO[addrO];
        end
    end

    // ------------------------------------------------------------------------
    // Controller read ports: A, B, I (combinational read from memories)
    // ------------------------------------------------------------------------
    logic [ADDR_A_W-1:0] addrA_r;
    logic [ADDR_B_W-1:0] addrB_r;
    logic [ADDR_I_W-1:0] instr_addr;
    logic [DATA_W-1:0]   dataA_r, dataB_r;
    logic [INSTR_W-1:0]  instr_dout;

    assign dataA_r    = memA[addrA_r];
    assign dataB_r    = memB[addrB_r];
    assign instr_dout = memI[instr_addr];

    // ------------------------------------------------------------------------
    // Controller write port for O (writes results during S_RUN when sa_out_valid)
    // ------------------------------------------------------------------------
    logic [ADDR_O_W-1:0] addrO_w;
    logic [DATA_W-1:0]   dataO_w;
    logic                weO;

    always_ff @(posedge clk) begin
        if (rst_n && weO) begin
            memO[addrO_w] <= dataO_w;
        end
    end

    // ------------------------------------------------------------------------
    // Systolic array <-> controller signals
    // ------------------------------------------------------------------------
    logic        sa_start, sa_clear, sa_done, sa_out_valid;
    logic [DATA_W-1:0] sa_in_a, sa_in_b;
    logic [ACC_W-1:0]  sa_out_data;

    // ------------------------------------------------------------------------
    // Controller instance
    // ------------------------------------------------------------------------
    controller #(
        .N        (N),
        .DATA_W   (DATA_W),
        .ACC_W    (ACC_W),
        .INSTR_W  (INSTR_W),
        .ADDR_A_W (ADDR_A_W),
        .ADDR_B_W (ADDR_B_W),
        .ADDR_O_W (ADDR_O_W),
        .ADDR_I_W (ADDR_I_W)
    ) u_controller (
        .clk        (clk),
        .rst_n      (rst_n),
        .ap_start   (ap_start),
        .ap_done    (ap_done),
        .instr_addr (instr_addr),
        .instr_dout (instr_dout),
        .addrA_r    (addrA_r),
        .dataA_r    (dataA_r),
        .addrB_r    (addrB_r),
        .dataB_r    (dataB_r),
        .addrO_w    (addrO_w),
        .dataO_w    (dataO_w),
        .weO        (weO),
        .sa_start   (sa_start),
        .sa_clear   (sa_clear),
        .sa_done    (sa_done),
        .sa_in_a    (sa_in_a),
        .sa_in_b    (sa_in_b),
        .sa_out_data(sa_out_data),
        .sa_out_valid(sa_out_valid)
    );

    // ------------------------------------------------------------------------
    // Systolic array instance
    // ------------------------------------------------------------------------
    systolic_array #(
        .N      (N),
        .DATA_W (DATA_W),
        .ACC_W  (ACC_W)
    ) u_systolic_array (
        .clk         (clk),
        .rst_n       (rst_n),
        .clear       (sa_clear),
        .start       (sa_start),
        .sa_in_a     (sa_in_a),
        .sa_in_b     (sa_in_b),
        .sa_out_data (sa_out_data),
        .sa_out_valid(sa_out_valid),
        .sa_done     (sa_done)
    );

endmodule