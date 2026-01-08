// Generic data memory for matrices A, B, or O.
// - Single read/write port
// - Synchronous read (dout updates on clock edge)

module data_mem #(
    parameter int DATA_W = 16,
    parameter int DEPTH  = 2048,
    parameter int ADDR_W = $clog2(DEPTH)
)(
    input  logic                clk,
    input  logic                rst_n,

    input  logic                we,      // write enable
    input  logic [ADDR_W-1:0]   addr,
    input  logic [DATA_W-1:0]   din,
    output logic [DATA_W-1:0]   dout
);

    // Simple register array for storage
    logic [DATA_W-1:0] mem [0:DEPTH-1];

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


