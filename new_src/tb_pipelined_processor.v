

`timescale 1ns/1ps

// ============================================================================
// INSTRUCTION ENCODING MACROS  (Verilog-2005 compatible — plain concatenation)
// All register args must be passed as 3-bit literals, Imm6 as 6-bit, Imm9 as 9-bit
// ============================================================================
`define ADI(Rd,Rs,I6)    {4'b0000,(Rd),(Rs),(I6)}
`define ADD(Rd,R1,R2)    {4'b0001,(Rd),(R1),(R2),3'b000}
`define ADC(Rd,R1,R2)    {4'b0001,(Rd),(R1),(R2),3'b010}
`define ADZ(Rd,R1,R2)    {4'b0001,(Rd),(R1),(R2),3'b001}
`define NDU(Rd,R1,R2)    {4'b0010,(Rd),(R1),(R2),3'b000}
`define LHI(Rd,I9)       {4'b0011,(Rd),(I9)}
`define LW(Rs,Rd,I6)     {4'b0100,(Rs),(Rd),(I6)}
`define SW(Rs1,Rs2,I6)   {4'b0101,(Rs1),(Rs2),(I6)}
`define BEQ(R1,R2,I6)    {4'b1000,(R1),(R2),(I6)}
`define JAL(Rd,I9)       {4'b1001,(Rd),(I9)}
`define JRI(Rs,I9)       {4'b1011,(Rs),(I9)}
`define NOP              16'b0111_000_000_000_000

// Convenience 3-bit register constants
`define R0 3'd0
`define R1 3'd1
`define R2 3'd2
`define R3 3'd3
`define R4 3'd4
`define R5 3'd5
`define R6 3'd6
`define R7 3'd7

module tb_pipelined_processor;

    // -----------------------------------------------------------------------
    // DUT ports
    // -----------------------------------------------------------------------
    reg         clk, reset;
    reg         instr_we;
    reg  [3:0]  instr_waddr;
    reg  [15:0] instr_wdata;
    reg  [2:0]  debug_reg_addr;
    reg  [5:0]  debug_mem_addr;
    wire [15:0] pc_out_port;
    wire [15:0] debug_reg_data;
    wire [15:0] debug_mem_data;
    wire        zero_flag_port;
    wire        carry_flag_port;

    // -----------------------------------------------------------------------
    // Score keeping
    // -----------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    pipelined_processor dut (
        .clk            (clk),
        .reset          (reset),
        .instr_we       (instr_we),
        .instr_waddr    (instr_waddr),
        .instr_wdata    (instr_wdata),
        .debug_reg_addr (debug_reg_addr),
        .debug_mem_addr (debug_mem_addr),
        .pc_out_port    (pc_out_port),
        .debug_reg_data (debug_reg_data),
        .debug_mem_data (debug_mem_data),
        .zero_flag_port (zero_flag_port),
        .carry_flag_port(carry_flag_port)
    );

    // -----------------------------------------------------------------------
    // 10 ns clock
    // -----------------------------------------------------------------------
    initial clk = 0;
    always  #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Tasks
    // -----------------------------------------------------------------------

    task write_instr;
        input [3:0]  addr;
        input [15:0] instr;
        begin
            @(negedge clk);
            instr_we    = 1'b1;
            instr_waddr = addr;
            instr_wdata = instr;
            @(negedge clk);
            instr_we    = 1'b0;
        end
    endtask

    task do_reset;
        begin
            reset = 1'b1;
            repeat(3) @(negedge clk);
            reset = 1'b0;
        end
    endtask

    task run_cycles;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // Check register — label is a 96-bit packed string (12 chars)
    task check_reg;
        input [2:0]       raddr;
        input [15:0]      expected;
        input [8*12-1:0]  lbl;
        begin
            debug_reg_addr = raddr;
            #1;
            test_num = test_num + 1;
            if (debug_reg_data === expected) begin
                $display("  [PASS] #%-2d  %-12s  R%0d = 0x%04h  (exp 0x%04h)",
                         test_num, lbl, raddr, debug_reg_data, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] #%-2d  %-12s  R%0d = 0x%04h  (exp 0x%04h)  <---",
                         test_num, lbl, raddr, debug_reg_data, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_flag;
        input            actual;
        input            expected;
        input [8*12-1:0] lbl;
        begin
            test_num = test_num + 1;
            if (actual === expected) begin
                $display("  [PASS] #%-2d  %-12s  flag=%0b  (exp %0b)",
                         test_num, lbl, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] #%-2d  %-12s  flag=%0b  (exp %0b)  <---",
                         test_num, lbl, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_mem;
        input [5:0]       maddr;
        input [15:0]      expected;
        input [8*12-1:0]  lbl;
        begin
            debug_mem_addr = maddr;
            #1;
            test_num = test_num + 1;
            if (debug_mem_data === expected) begin
                $display("  [PASS] #%-2d  %-12s  MEM[%0d]=0x%04h  (exp 0x%04h)",
                         test_num, lbl, maddr, debug_mem_data, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] #%-2d  %-12s  MEM[%0d]=0x%04h  (exp 0x%04h)  <---",
                         test_num, lbl, maddr, debug_mem_data, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =======================================================================
    // MAIN
    // =======================================================================
    initial begin
        $dumpfile("tb_pipelined_processor.vcd");
        $dumpvars(0, tb_pipelined_processor);

        reset          = 0;
        instr_we       = 0;
        instr_waddr    = 0;
        instr_wdata    = 0;
        debug_reg_addr = 0;
        debug_mem_addr = 0;
        pass_count     = 0;
        fail_count     = 0;
        test_num       = 0;

        $display("=================================================================");
        $display("  Pipelined Processor Testbench  (iverilog -g2005)");
        $display("  ISA: ADI ADD ADC ADZ NDU LHI LW SW BEQ JAL JRI");
        $display("=================================================================");

        // -------------------------------------------------------------------
        // GROUP 1 — ADI
        // -------------------------------------------------------------------
        $display("\n--- GROUP 1: ADI (Rd = Rs + Imm6) ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd5));
        write_instr(4'd1,  `NOP);
        write_instr(4'd2,  `ADI(`R2,`R1,6'd10));
        write_instr(4'd3,  `ADI(`R3,`R0,6'b111101));   // -3 (6-bit 2's comp)
        write_instr(4'd4,  `ADI(`R4,`R0,6'd0));
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `NOP);
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `NOP);
        do_reset;
        run_cycles(14);
        check_reg(`R1, 16'd5,    "ADI R1=5    ");
        check_reg(`R2, 16'd15,   "ADI R2=15   ");
        check_reg(`R3, 16'hFFFD, "ADI R3=-3   ");
        check_reg(`R4, 16'd0,    "ADI R4=0    ");

        // -------------------------------------------------------------------
        // GROUP 2 — ADD
        // -------------------------------------------------------------------
        $display("\n--- GROUP 2: ADD (Rd = Rs1 + Rs2) ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd20));
        write_instr(4'd1,  `ADI(`R2,`R0,6'd22));
        write_instr(4'd2,  `NOP);
        write_instr(4'd3,  `ADD(`R3,`R1,`R2));
        write_instr(4'd4,  `ADD(`R4,`R0,`R0));
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `NOP);
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `NOP);
        do_reset;
        run_cycles(16);
        check_reg(`R3, 16'd42, "ADD R3=42   ");
        check_reg(`R4, 16'd0,  "ADD R4=0    ");

        // -------------------------------------------------------------------
        // GROUP 3 — NDU
        // -------------------------------------------------------------------
        $display("\n--- GROUP 3: NDU (Rd = ~(Rs1 & Rs2)) ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd5));
        write_instr(4'd1,  `ADI(`R2,`R0,6'd3));
        write_instr(4'd2,  `NOP);
        write_instr(4'd3,  `NDU(`R3,`R1,`R2));   // ~(5&3)=~1=0xFFFE
        write_instr(4'd4,  `NDU(`R4,`R0,`R0));   // ~(0&0)=0xFFFF
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `NOP);
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `NOP);
        do_reset;
        run_cycles(16);
        check_reg(`R3, 16'hFFFE, "NDU R3=FFFE ");
        check_reg(`R4, 16'hFFFF, "NDU R4=FFFF ");

        // -------------------------------------------------------------------
        // GROUP 4 — LHI
        // -------------------------------------------------------------------
        $display("\n--- GROUP 4: LHI (Rd[15:7]=Imm9) ---");
        do_reset;
        write_instr(4'd0,  `LHI(`R1,9'd1));      // 0x0080
        write_instr(4'd1,  `LHI(`R2,9'd255));    // 0x7F80
        write_instr(4'd2,  `LHI(`R3,9'd0));      // 0x0000
        write_instr(4'd3,  `NOP);
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `NOP);
        do_reset;
        run_cycles(12);
        check_reg(`R1, 16'h0080, "LHI R1=0080 ");
        check_reg(`R2, 16'h7F80, "LHI R2=7F80 ");
        check_reg(`R3, 16'h0000, "LHI R3=0    ");

        // -------------------------------------------------------------------
        // GROUP 5 — SW / LW
        // -------------------------------------------------------------------
        $display("\n--- GROUP 5: SW / LW ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd7));   // R1=7
        write_instr(4'd1,  `NOP);
        write_instr(4'd2,  `NOP);
        write_instr(4'd3,  `SW(`R0,`R1,6'd3));        // MEM[0+3]=MEM[3]=7
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `LW(`R0,`R3,6'd3));        // R3=MEM[3]=7
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `NOP);
        write_instr(4'd9,  `NOP);
        write_instr(4'd10, `NOP);
        write_instr(4'd11, `NOP);
        write_instr(4'd12, `NOP);
        write_instr(4'd12, `NOP);
        write_instr(4'd13, `NOP);
        write_instr(4'd14, `NOP);
        write_instr(4'd15, `NOP);
        do_reset;
        run_cycles(30);
        check_reg(`R3, 16'd7,    "LW  R3=7    ");
        check_mem(6'd3,  16'd7,  "SW  MEM3=7  ");

        // -------------------------------------------------------------------
        // GROUP 6 — Load-Use Stall
        // -------------------------------------------------------------------
        $display("\n--- GROUP 6: Load-Use Stall ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd5));
        write_instr(4'd1,  `ADI(`R2,`R0,6'd0));
        write_instr(4'd2,  `NOP);
        write_instr(4'd3,  `SW(`R2,`R1,6'd0));        // MEM[0]=5
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `LW(`R2,`R3,6'd0));        // R3=5  (load)
        write_instr(4'd6,  `ADD(`R4,`R3,`R1));        // stall: R4=R3+R1=10
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `NOP);
        write_instr(4'd9,  `NOP);
        write_instr(4'd10, `NOP);
        write_instr(4'd11, `NOP);
        do_reset;
        run_cycles(26);
        check_reg(`R3, 16'd5,  "LU  LW=5    ");
        check_reg(`R4, 16'd10, "LU  ADD=10  ");

        // -------------------------------------------------------------------
        // GROUP 7a — BEQ not taken
        // -------------------------------------------------------------------
        $display("\n--- GROUP 7: BEQ ---");
do_reset;
write_instr(4'd0,  `ADI(`R1,`R0,6'd1));
write_instr(4'd1,  `ADI(`R2,`R0,6'd2));
write_instr(4'd2,  `NOP);
write_instr(4'd3,  `BEQ(`R1,`R2,6'd3));      // not taken (1!=2)
write_instr(4'd4,  `ADI(`R3,`R0,6'd31));     // executed => R3=31  (was 63)
write_instr(4'd5,  `NOP);
write_instr(4'd6,  `NOP);
write_instr(4'd7,  `ADI(`R5,`R0,6'd25));
write_instr(4'd8,  `NOP);
write_instr(4'd9,  `NOP);
write_instr(4'd10, `NOP);
do_reset;
run_cycles(18);
check_reg(`R3, 16'd31, "BEQ not-takn");      // was 63

        // GROUP 7b — BEQ taken
        do_reset;
write_instr(4'd0,  `ADI(`R1,`R0,6'd5));
write_instr(4'd1,  `ADI(`R2,`R0,6'd5));
write_instr(4'd2,  `NOP);
write_instr(4'd3,  `BEQ(`R1,`R2,6'd1));      // taken => addr 5
write_instr(4'd4,  `ADI(`R3,`R0,6'd11));     // flushed
write_instr(4'd5,  `ADI(`R3,`R0,6'd25));     // target => R3=25  (was 55)
write_instr(4'd6,  `NOP);
write_instr(4'd7,  `NOP);
write_instr(4'd8,  `NOP);
write_instr(4'd9,  `NOP);
do_reset;
run_cycles(18);
check_reg(`R3, 16'd25, "BEQ taken   ");      // was 55



        // -------------------------------------------------------------------
        // GROUP 8 — JAL
        // -------------------------------------------------------------------
        $display("\n--- GROUP 8: JAL ---");
do_reset;
write_instr(4'd0,  `JAL(`R7,9'd2));          // R7=1, jump to addr 3
write_instr(4'd1,  `ADI(`R1,`R0,6'd11));     // flushed
write_instr(4'd2,  `ADI(`R1,`R0,6'd22));     // flushed
write_instr(4'd3,  `ADI(`R2,`R0,6'd25));     // R2=25  (was 55)
write_instr(4'd4,  `NOP);
write_instr(4'd5,  `NOP);
write_instr(4'd6,  `NOP);
write_instr(4'd7,  `NOP);
write_instr(4'd8,  `NOP);
do_reset;
run_cycles(18);
check_reg(`R7, 16'd1,  "JAL link=1  ");
check_reg(`R2, 16'd25, "JAL target  ");      // was 55
check_reg(`R1, 16'd0,  "JAL flushed ");



        // -------------------------------------------------------------------
        // GROUP 9 — JRI
        // -------------------------------------------------------------------
        $display("\n--- GROUP 9: JRI ---");
do_reset;
write_instr(4'd0,  `ADI(`R1,`R0,6'd3));      // R1=3
write_instr(4'd1,  `NOP);
write_instr(4'd2,  `JRI(`R1,9'd1));          // PC=3+1=4
write_instr(4'd3,  `ADI(`R2,`R0,6'd22));     // flushed
write_instr(4'd4,  `ADI(`R3,`R0,6'd30));     // R3=30  (was 62)
write_instr(4'd5,  `NOP);
write_instr(4'd6,  `NOP);
write_instr(4'd7,  `NOP);
write_instr(4'd8,  `NOP);
write_instr(4'd9,  `NOP);
do_reset;
run_cycles(18);
check_reg(`R3, 16'd30, "JRI target  ");      // was 62
check_reg(`R2, 16'd0,  "JRI flushed ");


        // -------------------------------------------------------------------
        // GROUP 10 — ADC
        // -------------------------------------------------------------------
        $display("\n--- GROUP 10: ADC ---");

        // 10a: carry=0 — ADC skipped
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd5));
        write_instr(4'd1,  `ADI(`R2,`R0,6'd3));
        write_instr(4'd2,  `NOP);
        write_instr(4'd3,  `ADC(`R3,`R1,`R2));        // skipped (carry=0)
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `NOP);
        write_instr(4'd7,  `NOP);
        do_reset;
        run_cycles(15);
        check_reg(`R3, 16'd0, "ADC skip C=0");

        // 10b: carry=1 — ADC executes
        do_reset;
write_instr(4'd0,  `ADI(`R5,`R0,6'd10));      // R5=10
write_instr(4'd1,  `ADI(`R6,`R0,6'd20));      // R6=20
write_instr(4'd2,  `LHI(`R1,9'd384));          // R1=0xC000
write_instr(4'd3,  `LHI(`R2,9'd384));          // R2=0xC000
write_instr(4'd4,  `NOP);
write_instr(4'd5,  `ADD(`R3,`R1,`R2));        // carry=1, R3=0x8000
write_instr(4'd6,  `ADC(`R7,`R5,`R6));        // carry=1 => R7=30
write_instr(4'd7,  `NOP);
write_instr(4'd8,  `NOP);
write_instr(4'd9,  `NOP);
write_instr(4'd10, `NOP);
write_instr(4'd11, `NOP);
write_instr(4'd12, `NOP);
write_instr(4'd13, `NOP);
do_reset;
run_cycles(11);
run_cycles(15);
check_reg(`R7, 16'd30, "ADC exec=30 ");
check_reg(`R0, 16'd0,  "R0 always 0 ");
check_reg(`R0, 16'd0,  "R0 no write ");
// (Removed the standalone 'ADC carry=1' flag check — fold into a separate
//  test that runs BEFORE the ADC, see Group 13 below.)



        // -------------------------------------------------------------------
        // GROUP 11 — ADZ
        // -------------------------------------------------------------------
        $display("\n--- GROUP 11: ADZ ---");

        // 11a: zero=0 — ADZ skipped
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd5));
        write_instr(4'd1,  `ADI(`R2,`R0,6'd3));
        write_instr(4'd2,  `NOP);
        write_instr(4'd3,  `ADZ(`R3,`R1,`R2));        // skipped (zero=0)
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `NOP);
        write_instr(4'd7,  `NOP);
        do_reset;
        run_cycles(15);
        check_reg(`R3, 16'd0, "ADZ skip Z=0");

        // 11b: zero=1 — ADZ executes
        do_reset;
        write_instr(4'd0,  `ADI(`R2,`R0,6'd7));        // R2=7
        write_instr(4'd1,  `ADI(`R3,`R0,6'd8));        // R3=8
        write_instr(4'd2,  `ADI(`R1,`R0,6'd0));        // zero=1
        write_instr(4'd3,  `NOP);
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `ADZ(`R4,`R2,`R3));         // zero=1 => R4=15
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `NOP);
        write_instr(4'd9,  `NOP);
        write_instr(4'd10, `NOP);
        do_reset;
        run_cycles(9);
        check_flag(zero_flag_port, 1'b1, "ADZ zero=1  ");
        run_cycles(13);
        check_reg(`R4, 16'd15, "ADZ exec=15 ");

        // -------------------------------------------------------------------
        // GROUP 12 — Integration: 1+2+3+4+5=15
        // -------------------------------------------------------------------
        $display("\n--- GROUP 12: Integration (sum 1..5 = 15) ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd1));
        write_instr(4'd1,  `ADI(`R2,`R0,6'd2));
        write_instr(4'd2,  `ADI(`R3,`R0,6'd3));
        write_instr(4'd3,  `ADI(`R4,`R0,6'd4));
        write_instr(4'd4,  `ADI(`R5,`R0,6'd5));
        write_instr(4'd5,  `NOP);
        write_instr(4'd6,  `ADD(`R6,`R1,`R2));         // R6=3
        write_instr(4'd7,  `NOP);
        write_instr(4'd8,  `ADD(`R6,`R6,`R3));         // R6=6
        write_instr(4'd9,  `NOP);
        write_instr(4'd10, `ADD(`R6,`R6,`R4));         // R6=10
        write_instr(4'd11, `NOP);
        write_instr(4'd12, `ADD(`R6,`R6,`R5));         // R6=15
        write_instr(4'd13, `NOP);
        write_instr(4'd14, `NOP);
        write_instr(4'd15, `NOP);
        do_reset;
        run_cycles(30);
        check_reg(`R6, 16'd15, "SUM 1..5=15 ");

        // -------------------------------------------------------------------
        // GROUP 13 — Carry flag from overflow
        // -------------------------------------------------------------------
        // ---- GROUP 13: Carry flag (replace block) ---------------------------------
// Use LHI to build operands; check carry IMMEDIATELY after the ADD
// (no other ADD/ADI/NDU may follow, or carry gets clobbered).
$display("\n--- GROUP 13: Carry flag (ADD overflow) ---");
do_reset;
write_instr(4'd0,  `LHI(`R1,9'd384));        // R1=0xC000
write_instr(4'd1,  `LHI(`R2,9'd384));        // R2=0xC000
write_instr(4'd2,  `NOP);
write_instr(4'd3,  `ADD(`R3,`R1,`R2));       // 0xC000+0xC000 = 0x18000 -> carry=1, R3=0x8000
write_instr(4'd4,  `NOP);
write_instr(4'd5,  `NOP);
write_instr(4'd6,  `NOP);
write_instr(4'd7,  `NOP);
write_instr(4'd8,  `NOP);
do_reset;
run_cycles(11);
check_reg(`R3, 16'h8000, "ADD overflow");
        check_flag(carry_flag_port, 1'b1, "Carry=1     ");
        $display("  DEBUG carry=%b zero=%b", carry_flag_port, zero_flag_port);


        // -------------------------------------------------------------------
        // GROUP 14 — Zero flag from ADI result=0
        // -------------------------------------------------------------------
        $display("\n--- GROUP 14: Zero flag (ADI result=0) ---");
        do_reset;
        write_instr(4'd0,  `ADI(`R1,`R0,6'd5));        // zero=0
        write_instr(4'd1,  `NOP);
        write_instr(4'd2,  `ADI(`R2,`R0,6'd0));        // zero=1
        write_instr(4'd3,  `NOP);
        write_instr(4'd4,  `NOP);
        write_instr(4'd5,  `NOP);
        do_reset;
        run_cycles(12);
        check_flag(zero_flag_port, 1'b1, "Zero=1      ");

        // -------------------------------------------------------------------
        // SUMMARY
        // -------------------------------------------------------------------
        $display("\n=================================================================");
        $display("  RESULTS:  %0d PASSED   %0d FAILED   (Total %0d tests)",
                 pass_count, fail_count, test_num);
        $display("=================================================================");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** %0d FAILURE(S) detected — see <--- markers above ***",
                     fail_count);
        $display("=================================================================\n");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("[TIMEOUT] 100 us elapsed — check for deadlock.");
        $finish;
    end

endmodule

