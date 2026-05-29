// Instruction Memory — 16 slots of 16-bit instructions
// Initialized to NOP (0111000000000000)
// Supports runtime loading via instr_we interface
//
// NOTE: 'reset' must NOT clear the ROM contents — the testbench asserts
// reset AFTER loading the program in order to restart the PC. Clearing
// the ROM on reset wipes the program and the CPU then executes NOPs,
// leaving every register at 0.

module instr_mem
(
    input         clk, reset,
    input  [15:0] pc,
    output [15:0] instruction,
    input         instr_we,
    input  [3:0]  instr_waddr,
    input  [15:0] instr_wdata
);
    reg [15:0] rom [0:15];
    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1)
            rom[i] = 16'b0111000000000000; // NOP
    end

    always @(posedge clk) begin
        if (instr_we)
            rom[instr_waddr] <= instr_wdata;
    end

    // Output NOP if PC out of range
    assign instruction = (pc[15:4] == 12'b0) ? rom[pc[3:0]]
                                              : 16'b0111000000000000;

endmodule

