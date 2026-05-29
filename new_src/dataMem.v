// Data Memory — 64 x 16-bit
// Synchronous write, asynchronous read

module data_memory
(
    input         clk, rst,
    input  [15:0] mem_access_addr,
    input  [15:0] mem_write_data,
    input         mem_write_en,
    output [15:0] mem_read_data,
    input  [5:0]  debug_addr,
    output [15:0] debug_data
);
    reg [15:0] ram [0:63];
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1)
            ram[i] = 16'd0;
    end

    always @(posedge clk) begin
        if (mem_write_en && !rst)
            ram[mem_access_addr[5:0]] <= mem_write_data;
    end

    assign mem_read_data = ram[mem_access_addr[5:0]];
    assign debug_data    = ram[debug_addr];

endmodule

