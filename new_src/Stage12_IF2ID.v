// IF to ID Pipeline Register
module IF2ID_Pipline_Reg (
    input         clk, rst, enable,
    input  [15:0] PC_In, PC_Next_In, Instr_In,
    output reg [15:0] PC_Out, PC_Next_Out, Instr_Out
);
    initial begin
        PC_Out     = 0;
        PC_Next_Out = 0;
        Instr_Out  = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            PC_Out      <= 0;
            PC_Next_Out <= 0;
            Instr_Out   <= 0;
        end else if (enable) begin
            PC_Out      <= PC_In;
            PC_Next_Out <= PC_Next_In;
            Instr_Out   <= Instr_In;
        end
    end

endmodule

