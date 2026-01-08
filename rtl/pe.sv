// Single processing element (PE) for the systolic array.
// For this project we keep the accumulator local to the PE:
// - No acc_in/acc_out chaining between PEs.
// - Each PE computes one dot-product (one C[i,j]) over multiple cycles.

module pe #(
    parameter int DATA_W = 16,
    parameter int ACC_W  = 32
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                clear,      // clear accumulator before a new MMM

    input  logic [DATA_W-1:0]   in_a,       // from left
    input  logic [DATA_W-1:0]   in_b,       // from top
    output logic [DATA_W-1:0]   out_a,      // to right
    output logic [DATA_W-1:0]   out_b,      // to bottom
    output logic [ACC_W-1:0]    acc_out     // local accumulated result
);

    // Local accumulator register.
    // Over multiple cycles, this will build up the dot product.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= '0;
            out_a   <= '0;
            out_b   <= '0;
        end else begin
            // Pass A and B values through to neighbors every cycle.
            out_a <= in_a;
            out_b <= in_b;

            if (clear) begin
                acc_out <= '0;
            end else begin
                acc_out <= acc_out + (in_a * in_b);
            end
        end
    end

endmodule