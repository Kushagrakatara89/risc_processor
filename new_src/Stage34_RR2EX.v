// RR to EX Pipeline Register
// cntrl format: {RR_A3_Address_sel[1:0], RR_Wr_En, EXE_ALU_Src[1:0], EXE_ALU_Oper[1:0], Reg_D3_Sel[1:0], MEM_Wr_En} = 10 bits

module RR2EX_Pipline_Reg (
    input         clk, rst, enable,
    input  [15:0] pc_in, pc_next_in, instr_in,
    input  [15:0] RF_D1_In, RF_D2_In,
    input  [2:0]  RF_A1_In, RF_A2_In,
    input  [9:0]  cntrl_in,
    output reg [15:0] pc_out, pc_next_out, instr_out,
    output reg [15:0] RF_D1_Out, RF_D2_Out,
    output reg [2:0]  RF_A1_Out, RF_A2_Out,
    output reg [9:0]  cntrl_out
);
    initial begin
        pc_out     = 0; pc_next_out = 0; instr_out = 0;
        RF_D1_Out  = 0; RF_D2_Out   = 0;
        RF_A1_Out  = 0; RF_A2_Out   = 0;
        cntrl_out  = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            pc_out      <= 0;
            pc_next_out <= 0;
            instr_out   <= 0;
            RF_D1_Out   <= 0;
            RF_D2_Out   <= 0;
            RF_A1_Out   <= 0;
            RF_A2_Out   <= 0;
            cntrl_out   <= 0;
        end else if (enable) begin
            pc_out      <= pc_in;
            pc_next_out <= pc_next_in;
            instr_out   <= instr_in;
            RF_D1_Out   <= RF_D1_In;
            RF_D2_Out   <= RF_D2_In;
            RF_A1_Out   <= RF_A1_In;
            RF_A2_Out   <= RF_A2_In;
            cntrl_out   <= cntrl_in;
        end
    end

endmodule

