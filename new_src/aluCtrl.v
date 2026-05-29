// ALU Control — handles flag writes and conditional execution
// Supports: ADI, ADD, ADC, ADZ, NDU

module alu_ctrl
(
    input  [15:0] instr,
    input         carry_in,
    input         zero_in,
    input         reg_write_enable_in,
    output reg    carry_write_en,
    output reg    zero_write_en,
    output reg    reg_write_enable_out,
    output reg [1:0] alu_operation_out
);
    // {opcode[3:0], lsb2[1:0]} = 6 bits
    wire [5:0] ALUControlIn;
    assign ALUControlIn = {instr[15:12], instr[1:0]};

    localparam ADD = 6'b000100;  // opcode=0001, lsb2=00
    localparam ADC = 6'b000110;  // opcode=0001, lsb2=10
    localparam ADZ = 6'b000101;  // opcode=0001, lsb2=01
    localparam NDU = 6'b001000;  // opcode=0010, lsb2=00

    localparam ALU_ADD  = 2'b00;
    localparam ALU_NAND = 2'b01;
    localparam ALU_NOP  = 2'b10;

    always @(*) begin
        // defaults
        carry_write_en       = 1'b0;
        zero_write_en        = 1'b0;
        reg_write_enable_out = reg_write_enable_in;
        alu_operation_out    = ALU_NOP;

        casez (ALUControlIn)
            // ADI: opcode=0000, any lsb2
            6'b0000??: begin
                if (reg_write_enable_in) begin
                    alu_operation_out = ALU_ADD;
                    carry_write_en    = 1'b1;
                    zero_write_en     = 1'b1;
                end
            end
            // ADD
            ADD: begin
                if (reg_write_enable_in) begin
                    alu_operation_out = ALU_ADD;
                    carry_write_en    = 1'b1;
                    zero_write_en     = 1'b1;
                end
            end
            // ADC: execute only if carry=1
            ADC: begin
                if (reg_write_enable_in && carry_in) begin
                    alu_operation_out = ALU_ADD;
                    carry_write_en    = 1'b1;
                    zero_write_en     = 1'b1;
                end else begin
                    alu_operation_out    = ALU_NOP;
                    reg_write_enable_out = 1'b0;
                end
            end
            // ADZ: execute only if zero=1
            ADZ: begin
                if (reg_write_enable_in && zero_in) begin
                    alu_operation_out = ALU_ADD;
                    carry_write_en    = 1'b1;
                    zero_write_en     = 1'b1;
                end else begin
                    alu_operation_out    = ALU_NOP;
                    reg_write_enable_out = 1'b0;
                end
            end
            // NDU
            NDU: begin
                if (reg_write_enable_in) begin
                    alu_operation_out = ALU_NAND;
                    zero_write_en     = 1'b1;
                end
            end
            default: begin
                // NOP — defaults already set
            end
        endcase
    end

endmodule

