// Control Decoder — supports: ADI, ADD, NDU, LW, SW, BEQ, JAL, JRI, LHI, ADC, ADZ
// Instruction formats:
//   ADI : {0000, Rd[11:9],  Rs[8:6],  Imm6[5:0]}
//   ADD : {0001, Rd[11:9],  Rs1[8:6], Rs2[5:3], 2'b00}
//   ADC : {0001, Rd[11:9],  Rs1[8:6], Rs2[5:3], 2'b10}  lsb2=10
//   ADZ : {0001, Rd[11:9],  Rs1[8:6], Rs2[5:3], 2'b01}  lsb2=01
//   NDU : {0010, Rd[11:9],  Rs1[8:6], Rs2[5:3], 2'b00}
//   LHI : {0011, Rd[11:9],  Imm9[8:0]}
//   LW  : {0100, Rs[11:9],  Rd[8:6],  Imm6[5:0]}
//   SW  : {0101, Rs1[11:9], Rs2[8:6], Imm6[5:0]}
//   BEQ : {1000, Rs1[11:9], Rs2[8:6], Imm6[5:0]}
//   JAL : {1001, Rd[11:9],  Imm9[8:0]}
//   JRI : {1011, Rs[11:9],  Imm9[8:0]}

module control_decoder (
    input  [3:0] opcode,
    input  [1:0] ir_lsb_2,          // needed for ADC/ADZ distinction
    output reg   RR_A1_Address_sel,  // 0=ir[11:9], 1=ir[8:6]
    output reg   RR_A2_Address_sel,  // 0=ir[8:6],  1=ir[11:9]
    output reg [1:0] RR_A3_Address_sel, // 00=ir[11:9], 01=ir[8:6], 10=ir[11:9](for LHI/JAL)
    output reg   RR_Wr_En,
    output reg [1:0] EXE_ALU_Src,   // 00=reg, 01=imm6, 10=LHI shifted
    output reg [1:0] EXE_ALU_Oper,  // 00=ADD, 01=NAND, 10=LHI passthrough
    output reg [1:0] Reg_D3_Sel,    // 00=ALU result, 01=Memory out, 10=LHI
    output reg   MEM_Wr_En,
    output reg   pc_data_select     // 1=JAL/JRI
);

always @(*) begin
    // safe defaults
    RR_A1_Address_sel = 1'b0;
    RR_A2_Address_sel = 1'b0;
    RR_A3_Address_sel = 2'b00;
    RR_Wr_En          = 1'b0;
    EXE_ALU_Src       = 2'b00;
    EXE_ALU_Oper      = 2'b00;
    Reg_D3_Sel        = 2'b00;
    MEM_Wr_En         = 1'b0;
    pc_data_select    = 1'b0;

    case (opcode)
        4'b0000: begin  // ADI: Rd = Rs + Imm6
            RR_A1_Address_sel = 1'b1;   // read Rs from ir[8:6]
            RR_A2_Address_sel = 1'b1;   // not used
            RR_A3_Address_sel = 2'b10;  // write Rd = ir[11:9]
            RR_Wr_En          = 1'b1;
            EXE_ALU_Src       = 2'b01;  // src B = imm6
            EXE_ALU_Oper      = 2'b00;  // ADD
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
        end

        4'b0001: begin  // ADD / ADC / ADZ: Rd[11:9] = Rs1[8:6] + Rs2[5:3]
            RR_A1_Address_sel = 1'b1;   // Rs1 from ir[8:6]
            RR_A2_Address_sel = 1'b0;   // Rs2 from ir[5:3]
            RR_A3_Address_sel = 2'b00;  // write Rd = ir[11:9]
            RR_Wr_En          = 1'b1;
            EXE_ALU_Src       = 2'b00;  // src B = register
            EXE_ALU_Oper      = 2'b00;  // ADD
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
        end

        4'b0010: begin  // NDU: Rd = ~(Rs1 & Rs2)
            RR_A1_Address_sel = 1'b1;   // Rs1 from ir[8:6]
            RR_A2_Address_sel = 1'b0;   // Rs2 from ir[5:3]
            RR_A3_Address_sel = 2'b00;  // write Rd = ir[11:9]
            RR_Wr_En          = 1'b1;
            EXE_ALU_Src       = 2'b00;
            EXE_ALU_Oper      = 2'b01;  // NAND
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
        end

        4'b0011: begin  // LHI: Rd = Imm9 << 7
            RR_A1_Address_sel = 1'b1;   // not used
            RR_A2_Address_sel = 1'b1;   // not used
            RR_A3_Address_sel = 2'b10;  // write Rd = ir[11:9]
            RR_Wr_En          = 1'b1;
            EXE_ALU_Src       = 2'b10;  // LHI shifted immediate
            EXE_ALU_Oper      = 2'b10;  // LHI passthrough
            Reg_D3_Sel        = 2'b10;  // write LHI result
            MEM_Wr_En         = 1'b0;
        end

        4'b0100: begin  // LW: Rd = mem[Rs + Imm6]
            RR_A1_Address_sel = 1'b0;   // read Rs from ir[11:9]
            RR_A2_Address_sel = 1'b1;   // not used
            RR_A3_Address_sel = 2'b01;  // write Rd = ir[8:6]
            RR_Wr_En          = 1'b1;
            EXE_ALU_Src       = 2'b01;  // src B = imm6
            EXE_ALU_Oper      = 2'b00;  // ADD (compute address)
            Reg_D3_Sel        = 2'b01;  // write memory output
            MEM_Wr_En         = 1'b0;
        end

        4'b0101: begin  // SW: mem[Rs1+Imm6] = Rs2
            RR_A1_Address_sel = 1'b0;   // Rs1 from ir[11:9] (address base)
            RR_A2_Address_sel = 1'b1;   // Rs2 from ir[8:6]  (data)
            RR_A3_Address_sel = 2'b00;
            RR_Wr_En          = 1'b0;
            EXE_ALU_Src       = 2'b01;  // imm6
            EXE_ALU_Oper      = 2'b00;
            Reg_D3_Sel        = 2'b01;
            MEM_Wr_En         = 1'b1;
        end

        4'b1000: begin  // BEQ: Rs1[11:9] == Rs2[8:6]
            RR_A1_Address_sel = 1'b0;   // Rs1 from ir[11:9]
            RR_A2_Address_sel = 1'b1;   // Rs2 from ir[8:6]
            RR_A3_Address_sel = 2'b00;
            RR_Wr_En          = 1'b0;
            EXE_ALU_Src       = 2'b00;
            EXE_ALU_Oper      = 2'b00;
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
        end

        4'b1001: begin  // JAL: Rd = PC+1, PC = PC+1+Imm9
            RR_A1_Address_sel = 1'b1;   // not used
            RR_A2_Address_sel = 1'b1;   // not used
            RR_A3_Address_sel = 2'b10;  // write Rd = ir[11:9]
            RR_Wr_En          = 1'b1;
            EXE_ALU_Src       = 2'b00;
            EXE_ALU_Oper      = 2'b00;
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
            pc_data_select    = 1'b1;
        end

        4'b1011: begin  // JRI: PC = Rs + Imm9
            RR_A1_Address_sel = 1'b0;   // read Rs from ir[11:9]
            RR_A2_Address_sel = 1'b1;   // not used
            RR_A3_Address_sel = 2'b00;  // not used
            RR_Wr_En          = 1'b0;
            EXE_ALU_Src       = 2'b00;
            EXE_ALU_Oper      = 2'b00;
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
            pc_data_select    = 1'b1;
        end

        default: begin  // NOP
            RR_A1_Address_sel = 1'b0;
            RR_A2_Address_sel = 1'b0;
            RR_A3_Address_sel = 2'b00;
            RR_Wr_En          = 1'b0;
            EXE_ALU_Src       = 2'b00;
            EXE_ALU_Oper      = 2'b00;
            Reg_D3_Sel        = 2'b00;
            MEM_Wr_En         = 1'b0;
            pc_data_select    = 1'b0;
        end
    endcase
end

endmodule

