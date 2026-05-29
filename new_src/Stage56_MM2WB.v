// ============================================================================
// MM to WB Pipeline Register
// ============================================================================
module MEM2WB_Pipline_Reg (
    input         clk, rst, enable,
    input         RegWrite_In,              // NEW: register write enable in
    input  [2:0]  Rd_Addr_In_From_Mem,
    input  [15:0] Rd_Data_In_From_Mem,
    input  [15:0] Instr_In,
    output reg    RegWrite_Out,             // NEW: register write enable out
    output reg [2:0]  Rd_Addr_Out_PR,
    output reg [15:0] Rd_Data_Out_PR,
    output reg [15:0] Instr_Out
);

    initial begin
        RegWrite_Out   = 0;
        Rd_Addr_Out_PR = 0;
        Rd_Data_Out_PR = 0;
        Instr_Out      = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            RegWrite_Out   <= 0;
            Rd_Addr_Out_PR <= 0;
            Rd_Data_Out_PR <= 0;
            Instr_Out      <= 0;
        end else if (enable) begin
            RegWrite_Out   <= RegWrite_In;
            Rd_Addr_Out_PR <= Rd_Addr_In_From_Mem;
            Rd_Data_Out_PR <= Rd_Data_In_From_Mem;
            Instr_Out      <= Instr_In;
        end
    end

endmodule

