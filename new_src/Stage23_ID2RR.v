// ID to RR Pipeline Register
module ID2RR_Pipline_Reg (
    input         clk, rst, enable,
    input  [15:0] pc_in, pc_next_in, instr_in,
    input  [9:0]  cntrl_in,
    output reg [15:0] pc_out, pc_next_out, instr_out,
    output reg [9:0]  cntrl_out
);
    initial begin
        pc_out     = 0;
        pc_next_out = 0;
        instr_out  = 0;
        cntrl_out  = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            pc_out      <= 0;
            pc_next_out <= 0;
            instr_out   <= 0;
            cntrl_out   <= 0;
        end else if (enable) begin
            pc_out      <= pc_in;
            pc_next_out <= pc_next_in;
            instr_out   <= instr_in;
            cntrl_out   <= cntrl_in;
        end
    end

endmodule

