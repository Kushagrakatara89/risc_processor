`timescale 1ns/1ps

`define NOP 16'b0111_000_000_000000

module demo;
    reg clk=0, reset=0, instr_we=0;
    reg [3:0]  instr_waddr=0;
    reg [15:0] instr_wdata=0;
    reg [2:0]  debug_reg_addr=0;
    reg [5:0]  debug_mem_addr=0;
    wire [15:0] pc_out_port, debug_reg_data, debug_mem_data;
    wire zero_flag_port, carry_flag_port;

    pipelined_processor dut(
        .clk(clk), .reset(reset),
        .instr_we(instr_we), .instr_waddr(instr_waddr), .instr_wdata(instr_wdata),
        .debug_reg_addr(debug_reg_addr), .debug_mem_addr(debug_mem_addr),
        .pc_out_port(pc_out_port), .debug_reg_data(debug_reg_data),
        .debug_mem_data(debug_mem_data),
        .zero_flag_port(zero_flag_port), .carry_flag_port(carry_flag_port)
    );

    always #5 clk = ~clk;

    task load;
        input [3:0]  addr;
        input [15:0] instr;
        begin
            @(negedge clk); instr_we=1; instr_waddr=addr; instr_wdata=instr;
            @(negedge clk); instr_we=0;
        end
    endtask

    task load_all_nop;
        integer j;
        begin
            for (j=0; j<16; j=j+1)
                load(j[3:0], `NOP);
        end
    endtask

    initial begin
        $dumpfile("demo.vcd");
        $dumpvars(0, demo);

        // ================================================================
        
        // ================================================================
        // DEMO 3 — BEQ Taken (Branch + Pipeline Flush)
        // ================================================================
        $display("\n========================================");
        $display("  DEMO 3: BEQ TAKEN (Branch + Flush)");
        $display("========================================");

        reset=1; repeat(4) @(posedge clk); @(negedge clk); reset=0;
        load_all_nop;

        // [0]  ADI R1, R0, 7    => R1 = 7
        // [1]  ADI R2, R0, 7    => R2 = 7
        // [2]  NOP
        // [3]  BEQ R1,R2,+1    => TAKEN (7==7) jump to [5]
        // [4]  ADI R3, R0, 31  => FLUSHED must stay 0
        // [5]  ADI R4, R0, 20  => EXECUTES => R4=20
        // [6+] NOP

        load(4'd0,  16'b0000_001_000_000111); // ADI R1,R0,7
        load(4'd1,  16'b0000_010_000_000111); // ADI R2,R0,7
        load(4'd2,  `NOP);
        load(4'd3,  16'b1000_001_010_000001); // BEQ R1,R2,+1 (taken)
        load(4'd4,  16'b0000_011_000_011111); // ADI R3,R0,31 (FLUSHED)
        load(4'd5,  16'b0000_100_000_010100); // ADI R4,R0,20 (executes)
        load(4'd6,  `NOP);
        load(4'd7,  `NOP);
        load(4'd8,  `NOP);
        load(4'd9,  `NOP);
        load(4'd10, `NOP);
        load(4'd11, `NOP);
        load(4'd12, `NOP);
        load(4'd13, `NOP);
        load(4'd14, `NOP);
        load(4'd15, `NOP);

        reset=1; repeat(4) @(posedge clk); @(negedge clk); reset=0;
        repeat(30) @(posedge clk); #1;

        $display("--- Results ---");
        debug_reg_addr=3'd1; #1; $display("R1 = %0d  (expected 7)",  debug_reg_data);
        debug_reg_addr=3'd2; #1; $display("R2 = %0d  (expected 7)",  debug_reg_data);
        debug_reg_addr=3'd3; #1; $display("R3 = %0d  (expected 0)",  debug_reg_data);
        debug_reg_addr=3'd4; #1; $display("R4 = %0d  (expected 20)", debug_reg_data);
        $display("zero_flag  = %b  (expected 0)", zero_flag_port);
        $display("carry_flag = %b  (expected 0)", carry_flag_port);

        $display("\n========================================");
        $display("  ALL DEMOS COMPLETE");
        $display("========================================");
        $finish;
    end

    initial begin
        #200000;
        $display("WATCHDOG: timeout!");
        $finish;
    end

endmodule

