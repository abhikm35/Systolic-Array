module systolic_array #(
    parameter int N       = 4,
    parameter int DATA_W  = 16,
    parameter int ACC_W   = 32
)(
    input  logic              clk,
    input  logic              rst_n,

    input  logic              clear,        // from controller (sa_clear)
    input  logic              start,        // from controller (sa_start)

    // Streams from controller / memories
    input  logic [DATA_W-1:0] sa_in_a,      // A values (west edge)
    input  logic [DATA_W-1:0] sa_in_b,      // B values (north edge)

    // Results back to controller
    output logic [ACC_W-1:0]  sa_out_data,  // C elements
    output logic              sa_out_valid,
    output logic              sa_done
);

    // ------------------------------------------------------------------------
    // Internal wiring for PE mesh
    // ------------------------------------------------------------------------
    // a_bus: horizontal A values flowing from left to right.
    //  - Indexing: [row][column tap]
    //  - a_bus[r][c] feeds in_a of PE(r,c), out_a of that PE drives a_bus[r][c+1].
    logic [DATA_W-1:0] a_bus [0:N-1][0:N];

    // b_bus: vertical B values flowing from top to bottom.
    //  - b_bus[r][c] feeds in_b of PE(r,c), out_b of that PE drives b_bus[r+1][c].
    logic [DATA_W-1:0] b_bus [0:N][0:N-1];

    // Accumulators from each PE (local C elements).
    logic [ACC_W-1:0]  acc_grid [0:N-1][0:N-1];

    // ------------------------------------------------------------------------
    // Drive west and north edges from sa_in_a / sa_in_b (simple version)
    // ------------------------------------------------------------------------
    // For now, we only feed row 0 and column 0; other entries are 0.
    integer r, c;
    always_comb begin
        // Default all buses to zero
        for (r = 0; r < N; r++) begin
            for (c = 0; c <= N; c++) begin
                a_bus[r][c] = '0;
            end
        end
        for (r = 0; r <= N; r++) begin
            for (c = 0; c < N; c++) begin
                b_bus[r][c] = '0;
            end
        end

        // Inject one A stream at left of row 0 and one B stream at top of col 0
        a_bus[0][0] = sa_in_a;
        b_bus[0][0] = sa_in_b;
    end

    // ------------------------------------------------------------------------
    // Instantiate N x N PE grid and connect buses
    // ------------------------------------------------------------------------
    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : ROW
            for (j = 0; j < N; j++) begin : COL
                pe #(
                    .DATA_W(DATA_W),
                    .ACC_W (ACC_W)
                ) u_pe (
                    .clk    (clk),
                    .rst_n  (rst_n),
                    .clear  (clear),

                    .in_a   (a_bus[i][j]),
                    .in_b   (b_bus[i][j]),
                    .out_a  (a_bus[i][j+1]),
                    .out_b  (b_bus[i+1][j]),
                    .acc_out(acc_grid[i][j])
                );
            end
        end
    endgenerate

    // ------------------------------------------------------------------------
    // TODO: Output collection logic
    // For now, just expose acc_grid[0][0] as a placeholder.
    // ------------------------------------------------------------------------
    assign sa_out_data  = acc_grid[0][0];
    assign sa_out_valid = 1'b0;
    assign sa_done      = 1'b0;

endmodule