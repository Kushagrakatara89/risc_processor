// ============================================================================
// Comprehensive Testbench - IITB-RISC 6-Stage Pipelined Processor
// Vivado-compatible: plain 16-bit binary literals, no parameterized macros
// ============================================================================
// INSTRUCTION FORMAT:
//   ADI Rd,Rs,Imm6   : {4'b0000, Rd[2:0],  Rs[2:0],  Imm6[5:0]}
//   ADD Rd,Rs1,Rs2   : {4'b0001, Rs1[2:0], Rs2[2:0], Rd[2:0], 2'b00}
//   NDU Rd,Rs1,Rs2   : {4'b0010, Rs1[2:0], Rs2[2:0], Rd[2:0], 2'b00}
//   LHI Rd,Imm9      : {4'b0011, Rd[2:0],  Imm9[8:0]}
//   LW  Rd,Rs,Imm6   : {4'b0100, Rs[2:0],  Rd[2:0],  Imm6[5:0]}
//   SW  Rs2,Rs1,Imm6 : {4'b0101, Rs1[2:0], Rs2[2:0], Imm6[5:0]}
//   BEQ Rs1,Rs2,Imm6 : {4'b1000, Rs1[2:0], Rs2[2:0], Imm6[5:0]}
//   JAL Rd,Imm9      : {4'b1001, Rd[2:0],  Imm9[8:0]}
//   NOP              : 16'b0111_000_000_000000
// ============================================================================
`timescale 1ns/1ps

module topModuleTB_comprehe;

    reg          clk, reset;
    reg          instr_we;
    reg  [3:0]   instr_waddr;
    reg  [15:0]  instr_wdata;
    wire [15:0]  pc_out_port;
    wire [15:0]  ir_port;
    reg  [2:0]   debug_reg_addr;
    wire [15:0]  debug_reg_data;
    reg  [5:0]   debug_mem_addr;
    wire [15:0]  debug_mem_data;
    wire         zero_flag_port;
    wire         carry_flag_port;
    wire         processor_running;

    integer pass_count;
    integer fail_count;
    integer test_num;

    pipelined_processor dut (
        .clk              (clk),
        .reset            (reset),
        .instr_we         (instr_we),
        .instr_waddr      (instr_waddr),
        .instr_wdata      (instr_wdata),
        .pc_out_port      (pc_out_port),
        .ir_port          (ir_port),
        .debug_reg_addr   (debug_reg_addr),
        .debug_reg_data   (debug_reg_data),
        .debug_mem_addr   (debug_mem_addr),
        .debug_mem_data   (debug_mem_data),
        .zero_flag_port   (zero_flag_port),
        .carry_flag_port  (carry_flag_port),
        .processor_running(processor_running)
    );

    initial clk = 0;
    always #20 clk = ~clk;

    // -----------------------------------------------------------------------
    // Load one instruction into instruction memory
    // -----------------------------------------------------------------------
    task load_instr;
        input [3:0]  addr;
        input [15:0] instr;
        begin
            @(negedge clk);
            instr_we    = 1'b1;
            instr_waddr = addr;
            instr_wdata = instr;
            @(posedge clk);
            #1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Reset processor
    // -----------------------------------------------------------------------
    task do_reset;
        begin
            @(negedge clk);
            instr_we = 1'b0;
            reset    = 1'b1;
            repeat(3) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    // -----------------------------------------------------------------------
    // Run N cycles
    // -----------------------------------------------------------------------
    task run_cycles;
        input integer n;
        begin
            instr_we = 1'b0;
            repeat(n) @(posedge clk);
            #5;
        end
    endtask

    // -----------------------------------------------------------------------
    // Check register value
    // -----------------------------------------------------------------------
    task check_reg;
        input [2:0]  addr;
        input [15:0] expected;
        reg   [15:0] actual;
        begin
            test_num       = test_num + 1;
            debug_reg_addr = addr;
            #5;
            actual = debug_reg_data;
            if (actual === expected) begin
                $display("  PASS [%02d] R%0d = %0d (0x%04h)",
                         test_num, addr, actual, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%02d] R%0d = %0d (0x%04h)  expected %0d (0x%04h)",
                         test_num, addr, actual, actual, expected, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // MAIN TEST SEQUENCE
    // -----------------------------------------------------------------------
    initial begin
        pass_count     = 0;
        fail_count     = 0;
        test_num       = 0;
        clk            = 0;
        reset          = 0;
        instr_we       = 0;
        instr_waddr    = 0;
        instr_wdata    = 0;
        debug_reg_addr = 0;
        debug_mem_addr = 0;

        $display("==========================================================");
        $display("  IITB-RISC 6-Stage Pipeline Processor - Testbench");
        $display("==========================================================");

        // -------------------------------------------------------------------
        // GROUP 1: RESET
        // -------------------------------------------------------------------
        $display("\n--- GROUP 1: RESET ---");
        do_reset;
        run_cycles(5);
        check_reg(3'd1, 16'd0);
        check_reg(3'd2, 16'd0);

        // -------------------------------------------------------------------
        // GROUP 2: ADI
        // ADI Rd,Rs,Imm6 = {0000, Rd, Rs, Imm6}
        // R1=R0+5  : {0000,001,000,000101} = 16'b0000001000000101
        // R2=R0+10 : {0000,010,000,001010} = 16'b0000010000001010
        // R3=R0+63 : {0000,011,000,111111} = 16'b0000011000111111
        // R4=R1+1  : {0000,100,001,000001} = 16'b0000100001000001
        // -------------------------------------------------------------------
        $display("\n--- GROUP 2: ADI ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000101);
        load_instr(4'd1,  16'b0000010000001010);
        load_instr(4'd2,  16'b0000011000111111);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0000100001000001);
        load_instr(4'd5,  16'b0111000000000000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(20);
        check_reg(3'd1, 16'd5);
        check_reg(3'd2, 16'd10);
        check_reg(3'd3, 16'd63);
        check_reg(3'd4, 16'd6);

        // -------------------------------------------------------------------
        // GROUP 3: ADD
        // ADD Rd,Rs1,Rs2 = {0001, Rs1, Rs2, Rd, 00}
        // R1=5, R2=3
        // ADD R3,R1,R2 : {0001,001,010,011,00} = 16'b0001001010011000  -> 8
        // ADD R4,R3,R3 : {0001,011,011,100,00} = 16'b0001011011100000  -> 16
        // -------------------------------------------------------------------
        $display("\n--- GROUP 3: ADD ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000101);
        load_instr(4'd1,  16'b0000010000000011);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0001001010011000);
        load_instr(4'd5,  16'b0001011011100000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(25);
        check_reg(3'd3, 16'd8);
        check_reg(3'd4, 16'd16);

        // -------------------------------------------------------------------
        // GROUP 4: NDU (NAND)
        // NDU Rd,Rs1,Rs2 = {0010, Rs1, Rs2, Rd, 00}
        // R1=63, R2=63
        // NDU R3,R1,R2 : {0010,001,010,011,00} = 16'b0010001010011000 -> ~(63&63)=0xFFC0
        // NDU R4,R0,R0 : {0010,000,000,100,00} = 16'b0010000000100000 -> 0xFFFF
        // -------------------------------------------------------------------
        $display("\n--- GROUP 4: NDU (NAND) ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000111111);
        load_instr(4'd1,  16'b0000010000111111);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0010001010011000);
        load_instr(4'd5,  16'b0010000000100000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(25);
        check_reg(3'd3, 16'hFFC0);
        check_reg(3'd4, 16'hFFFF);

        // -------------------------------------------------------------------
        // GROUP 5: LHI
        // LHI Rd,Imm9 = {0011, Rd, Imm9}  result = {Imm9, 7'b0}
        // LHI R1,1 : {0011,001,000000001} = 16'b0011001000000001 -> 0x0080
        // LHI R2,2 : {0011,010,000000010} = 16'b0011010000000010 -> 0x0100
        // -------------------------------------------------------------------
        $display("\n--- GROUP 5: LHI ---");
        do_reset;
        load_instr(4'd0,  16'b0011001000000001);
        load_instr(4'd1,  16'b0011010000000010);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0111000000000000);
        load_instr(4'd5,  16'b0111000000000000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(20);
        check_reg(3'd1, 16'h0080);
        check_reg(3'd2, 16'h0100);

        // -------------------------------------------------------------------
        // GROUP 6: SW + LW
        // R1=42, R2=10
        // SW R1,R2,0 : {0101,Rs1=R2,Rs2=R1,000000} = 16'b0101010001000000
        // LW R3,R2,0 : {0100,Rs=R2, Rd=R3, 000000} = 16'b0100010011000000
        // -------------------------------------------------------------------
        $display("\n--- GROUP 6: SW + LW ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000101010);
        load_instr(4'd1,  16'b0000010000001010);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0101010001000000);
        load_instr(4'd5,  16'b0111000000000000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0100010011000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(35);
        check_reg(3'd3, 16'd42);

        // -------------------------------------------------------------------
        // GROUP 7: DATA FORWARDING back-to-back ADI chain
        // R1=1
        // R2=R1+1=2
        // R3=R2+1=3
        // R4=R3+1=4
        // R5=R4+1=5
        // -------------------------------------------------------------------
        $display("\n--- GROUP 7: FORWARDING (back-to-back) ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000001);
        load_instr(4'd1,  16'b0000010001000001);
        load_instr(4'd2,  16'b0000011010000001);
        load_instr(4'd3,  16'b0000100011000001);
        load_instr(4'd4,  16'b0000101100000001);
        load_instr(4'd5,  16'b0111000000000000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(25);
        check_reg(3'd1, 16'd1);
        check_reg(3'd2, 16'd2);
        check_reg(3'd3, 16'd3);
        check_reg(3'd4, 16'd4);
        check_reg(3'd5, 16'd5);

        // -------------------------------------------------------------------
        // GROUP 8: LOAD-USE HAZARD
        // R1=25, R2=15
        // SW R1,R2,0  -> mem[15]=25
        // LW R3,R2,0  -> R3=25
        // ADD R4,R3,R1 -> R4=50  (load-use hazard: pipeline must stall 1 cycle)
        // ADD R4,R3,R1 : {0001,011,001,100,00} = 16'b0001011001100000
        // -------------------------------------------------------------------
        $display("\n--- GROUP 8: LOAD-USE HAZARD ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000011001);
        load_instr(4'd1,  16'b0000010000001111);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0101010001000000);
        load_instr(4'd5,  16'b0111000000000000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0100010011000000);
        load_instr(4'd8,  16'b0001011001100000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(35);
        check_reg(3'd3, 16'd25);
        check_reg(3'd4, 16'd50);

        // -------------------------------------------------------------------
        // GROUP 9: BEQ TAKEN
        // R1=5, R2=5 -> equal -> branch taken
        // BEQ R1,R2,+2 at slot4 -> skip slot5, execute slot6
        // slot5: R3=63  (should be SKIPPED)
        // slot6: R4=7   (should EXECUTE)
        // BEQ : {1000,001,010,000010} = 16'b1000001010000010
        // R3=63: {0000,011,000,111111} = 16'b0000011000111111
        // R4=7 : {0000,100,000,000111} = 16'b0000100000000111
        // -------------------------------------------------------------------
        $display("\n--- GROUP 9: BEQ TAKEN ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000101);
        load_instr(4'd1,  16'b0000010000000101);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b1000001010000010);
        load_instr(4'd5,  16'b0000011000111111);
        load_instr(4'd6,  16'b0000100000000111);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(35);
        check_reg(3'd3, 16'd0);   // skipped -> stays 0
        check_reg(3'd4, 16'd7);   // executed

        // -------------------------------------------------------------------
        // GROUP 10: BEQ NOT TAKEN
        // R1=5, R2=3 -> not equal -> sequential execution continues
        // slot5: R3=55 should EXECUTE
        // BEQ : {1000,001,010,000100} = 16'b1000001010000100
        // R3=55: {0000,011,000,110111} = 16'b0000011000110111
        // -------------------------------------------------------------------
        $display("\n--- GROUP 10: BEQ NOT TAKEN ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000101);
        load_instr(4'd1,  16'b0000010000000011);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b1000001010000100);
        load_instr(4'd5,  16'b0000011000110111);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(30);
        check_reg(3'd3, 16'd55);

        // -------------------------------------------------------------------
        // GROUP 11: FIBONACCI
        // R1=0, R2=1
        // ADD R3,R1,R2 : {0001,001,010,011,00} = 16'b0001001010011000 -> 1
        // ADD R4,R2,R3 : {0001,010,011,100,00} = 16'b0001010011100000 -> 2 (wait NOPs)
        // ADD R5,R3,R4 : {0001,011,100,101,00} = 16'b0001011100101000 -> 3
        // ADD R6,R4,R5 : {0001,100,101,110,00} = 16'b0001100101110000 -> 5
        // -------------------------------------------------------------------
        $display("\n--- GROUP 11: FIBONACCI ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000000);
        load_instr(4'd1,  16'b0000010000000001);
        load_instr(4'd2,  16'b0111000000000000);
        load_instr(4'd3,  16'b0111000000000000);
        load_instr(4'd4,  16'b0001001010011000);
        load_instr(4'd5,  16'b0111000000000000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0001010011100000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0001011100101000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0001100101110000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(40);
        check_reg(3'd3, 16'd1);
        check_reg(3'd4, 16'd2);
        check_reg(3'd5, 16'd3);
        check_reg(3'd6, 16'd5);

        // -------------------------------------------------------------------
        // GROUP 12: FORWARDING STRESS - doubling chain (back-to-back ADD)
        // R1=1
        // ADD R2,R1,R1 : {0001,001,001,010,00} = 16'b0001001001010000 ->  2
        // ADD R3,R2,R2 : {0001,010,010,011,00} = 16'b0001010010011000 ->  4
        // ADD R4,R3,R3 : {0001,011,011,100,00} = 16'b0001011011100000 ->  8
        // ADD R5,R4,R4 : {0001,100,100,101,00} = 16'b0001100100101000 -> 16
        // ADD R6,R5,R5 : {0001,101,101,110,00} = 16'b0001101101110000 -> 32
        // -------------------------------------------------------------------
        $display("\n--- GROUP 12: FORWARDING STRESS (doubling) ---");
        do_reset;
        load_instr(4'd0,  16'b0000001000000001);
        load_instr(4'd1,  16'b0001001001010000);
        load_instr(4'd2,  16'b0001010010011000);
        load_instr(4'd3,  16'b0001011011100000);
        load_instr(4'd4,  16'b0001100100101000);
        load_instr(4'd5,  16'b0001101101110000);
        load_instr(4'd6,  16'b0111000000000000);
        load_instr(4'd7,  16'b0111000000000000);
        load_instr(4'd8,  16'b0111000000000000);
        load_instr(4'd9,  16'b0111000000000000);
        load_instr(4'd10, 16'b0111000000000000);
        load_instr(4'd11, 16'b0111000000000000);
        load_instr(4'd12, 16'b0111000000000000);
        load_instr(4'd13, 16'b0111000000000000);
        load_instr(4'd14, 16'b0111000000000000);
        load_instr(4'd15, 16'b0111000000000000);
        run_cycles(30);
        check_reg(3'd2, 16'd2);
        check_reg(3'd3, 16'd4);
        check_reg(3'd4, 16'd8);
        check_reg(3'd5, 16'd16);
        check_reg(3'd6, 16'd32);

        // -------------------------------------------------------------------
        // FINAL REPORT
        // -------------------------------------------------------------------
        $display("\n==========================================================");
        $display("  FINAL RESULTS");
        $display("==========================================================");
        $display("  PASSED : %0d", pass_count);
        $display("  FAILED : %0d", fail_count);
        $display("  TOTAL  : %0d", pass_count + fail_count);
        if (fail_count == 0)
            $display("  STATUS : ** ALL TESTS PASSED **");
        else
            $display("  STATUS : %0d TESTS FAILED", fail_count);
        $display("==========================================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #5000000;
        $display("TIMEOUT - simulation exceeded 5ms");
        $finish;
    end

endmodule
