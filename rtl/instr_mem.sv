// Instruction memory for the MMM instruction stream.
// Stores 16-bit (by default) instruction words: a, b, c, ..., 0.

module instr_mem #(
    parameter int INSTR_W = 16,
    parameter int DEPTH   = 64,
    parameter int ADDR_W  = $clog2(DEPTH)
)(
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 we,       // write enable (from testbench/CPU)
    input  logic [ADDR_W-1:0]    addr,
    input  logic [INSTR_W-1:0]   din,
    output logic [INSTR_W-1:0]   dout      // read by controller
);

    logic [INSTR_W-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= '0;
        end else begin
            if (we) begin
                mem[addr] <= din;
            end
            dout <= mem[addr];
        end
    end

endmodule


