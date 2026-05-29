// ALU — supports: ADD, NAND, LHI
// alu_control: 00=ADD, 01=NAND, 10=LHI(pass b), 11=NOP

module alu
(
    input  [15:0] a,
    input  [15:0] b,
    input  [1:0]  alu_control,
    output reg [15:0] result,
    output reg        zero,
    output reg        carry
);
    reg [16:0] total_sum;

    always @(*) begin
        result    = 16'd0;
        zero      = 1'b0;
        carry     = 1'b0;
        total_sum = 17'd0;

        case (alu_control)
            2'b00: begin  // ADD — used by ADI, ADD, ADC, ADZ, LW/SW address
                total_sum = {1'b0, a} + {1'b0, b};
                result    = total_sum[15:0];
                carry     = total_sum[16];
                zero      = (result == 16'd0) ? 1'b1 : 1'b0;
            end
            2'b01: begin  // NAND — used by NDU
                result = ~(a & b);
                zero   = (result == 16'd0) ? 1'b1 : 1'b0;
                carry  = 1'b0;
            end
            2'b10: begin  // LHI — pass b directly (shifted immediate)
                result = b;
                zero   = (result == 16'd0) ? 1'b1 : 1'b0;
                carry  = 1'b0;
            end
            default: begin  // NOP
                result = 16'd0;
                zero   = 1'b0;
                carry  = 1'b0;
            end
        endcase
    end

endmodule

