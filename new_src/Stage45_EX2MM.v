// EX to MM Pipeline Register
// Control_In format: {Reg_D3_Sel[1:0], Reg_Wr_En, Mem_Wr_En} = 4 bits (simplified)

module EX2MEM_Pipline_Reg (
    input         clk, rst, enable,
    input  [2:0]  Control_In,
    input  [2:0]  Rd_Addr_In_From_Ex,
    input  [15:0] Rd_Data_In_From_Ex,
    input  [15:0] RF_D2_In,
    input  [15:0] ALU_Result_In,
    input  [15:0] Instr_In,
    output reg [2:0]  Control_Out,
    output reg [2:0]  Rd_Addr_Out_PR,
    output reg [15:0] Rd_Data_Out_PR,
    output reg [15:0] RF_D2_Out,
    output reg [15:0] ALU_Result_Out,
    output reg [15:0] Instr_Out
);
    initial begin
        Control_Out    = 0; Rd_Addr_Out_PR = 0;
        Rd_Data_Out_PR = 0; RF_D2_Out      = 0;
        ALU_Result_Out = 0; Instr_Out      = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            Control_Out    <= 0;
            Rd_Addr_Out_PR <= 0;
            Rd_Data_Out_PR <= 0;
            RF_D2_Out      <= 0;
            ALU_Result_Out <= 0;
            Instr_Out      <= 0;
        end else if (enable) begin
            Control_Out    <= Control_In;
            Rd_Addr_Out_PR <= Rd_Addr_In_From_Ex;
            Rd_Data_Out_PR <= Rd_Data_In_From_Ex;
            RF_D2_Out      <= RF_D2_In;
            ALU_Result_Out <= ALU_Result_In;
            Instr_Out      <= Instr_In;
        end
    end

endmodule

