
module pipelined_processor (
    input         clk, reset,
    input         instr_we,
    input  [3:0]  instr_waddr,
    input  [15:0] instr_wdata,
    input  [2:0]  debug_reg_addr,
    input  [5:0]  debug_mem_addr,
    output [15:0] pc_out_port,
    output [15:0] debug_reg_data,
    output [15:0] debug_mem_data,
    output        zero_flag_port,
    output        carry_flag_port
);

    

    // PC and fetch
    wire [15:0] pc_out, pc_next, pc_current;
    wire [15:0] instruction, final_instr;
    wire        pc_enable;

    // IF/ID signals
    wire [15:0] pc_from_if_id, pc_next_from_if_id, ir_from_if_id;

    // Control signals from decoder
    wire        RR_A1_sel, RR_A2_sel, RR_Wr_En, MEM_Wr_En, pc_data_sel;
    wire [1:0]  RR_A3_sel, ALU_Src, ALU_Oper, Reg_D3_Sel;
    wire [9:0]  control_signals;

    // ID/RR signals
    wire [15:0] pc_from_id_rr, pc_next_from_id_rr, ir_from_id_rr;
    wire [9:0]  ctrl_from_id_rr;

    // RR stage
    wire [2:0]  A1_addr, A2_addr, A3_addr;
    wire [15:0] RF_D1, RF_D2;

    // RR/EX signals
    wire [15:0] pc_from_rr_ex, pc_next_from_rr_ex, ir_from_rr_ex;
    wire [15:0] RF_D1_from_rr_ex, RF_D2_from_rr_ex;
    wire [2:0]  A1_from_rr_ex, A2_from_rr_ex;
    wire [9:0]  ctrl_from_rr_ex;

    // EX stage
    wire [15:0] alu_src_A, alu_src_B, alu_out;
    wire [15:0] imm6, lhi_data;
    wire [1:0]  alu_op_final;
    wire        reg_wr_en_final;
    wire        carry_write_en, zero_write_en;
    wire        carry_flag_in, zero_flag_in;
    wire        carry_flag_out, zero_flag_out;
    wire [2:0]  rd_addr_at_ex;
    wire [15:0] rd_data_at_ex;
    wire [2:0]  new_ctrl_ex;   // {reg_wr_en, Reg_D3_Sel[1], mem_wr_en}

    // EX/MM signals
    wire [2:0]  ctrl_from_ex_mm, rd_addr_ex_mm;
    wire [15:0] rd_data_ex_mm, RF_D2_from_ex_mm, alu_from_ex_mm, ir_from_ex_mm;

    // MM stage
    wire [15:0] mem_out, rd_out_at_mem;
    wire        zero_wr_en_from_mem;
    reg         zero_flag_mem;

    // MM/WB signals
    wire        reg_wr_en_at_wb;
    wire [2:0]  rd_addr_at_wb;
    wire [15:0] rd_data_at_wb, ir_at_wb;

    // Hazard
    wire        load_use_hazard, nop_inject;
    reg         stall_pending;
    wire        pipe_en;        // 1=run, 0=stall

    // Branch/Jump
    reg  [15:0] pc_next_from_id, pc_next_from_ex;
    reg  [1:0]  pc_ctrl_id, pc_ctrl_ex;
    reg         flush_from_id, flush_from_ex;
    wire [1:0]  pc_select;
    wire [15:0] nop_instr;
    wire        nop_select;
    wire [15:0] pc_branch;

    // =========================================================================
    // FETCH STAGE
  
    assign pc_enable  = pipe_en & ~instr_we;
    assign pc_out_port = pc_out;

    register_n program_counter (
        .clk(clk), .reset(reset | instr_we),
        .enable(pc_enable), .in(pc_current), .out(pc_out)
    );

    assign pc_next = pc_out + 1;

    instr_mem imem (
        .clk(clk), .reset(reset), .pc(pc_out),
        .instruction(instruction),
        .instr_we(instr_we), .instr_waddr(instr_waddr), .instr_wdata(instr_wdata)
    );

    // Inject NOP on branch/jump flush
    assign nop_instr  = 16'b0111000000000000;
    assign nop_select = flush_from_id | flush_from_ex;

    mux_21 #(.IN_WIDTH(16),.OUT_WIDTH(16)) ir_nop_mux (
        .A(instruction), .B(nop_instr), .sel(nop_select), .O(final_instr)
    );

    // PC select mux: 00=pc_next, 01=JAL(from ID), 10=BEQ/JRI(from EX)
    branch_jump_controller bjc (
        .pc_control_from_ex(pc_ctrl_ex),
        .pc_control_from_id(pc_ctrl_id),
        .pc_select(pc_select)
    );

    mux_41 #(.IN_WIDTH(16),.OUT_WIDTH(16)) pc_mux (
        .A(pc_next), .B(pc_next_from_id),
        .C(pc_next_from_ex), .D(16'd0),
        .sel(pc_select), .O(pc_current)
    );

    // =========================================================================
    // IF/ID PIPELINE REGISTER
    // =========================================================================
    wire if_id_en = pipe_en & ~instr_we;
    wire if_id_rst = reset | flush_from_ex;

    IF2ID_Pipline_Reg if_id_reg (
        .clk(clk), .rst(if_id_rst), .enable(if_id_en),
        .PC_In(pc_out), .PC_Next_In(pc_next), .Instr_In(final_instr),
        .PC_Out(pc_from_if_id), .PC_Next_Out(pc_next_from_if_id),
        .Instr_Out(ir_from_if_id)
    );

    // ID STAGE — Decode + JAL detection
    
    control_decoder ctrl_dec (
        .opcode(ir_from_if_id[15:12]),
        .ir_lsb_2(ir_from_if_id[1:0]),
        .RR_A1_Address_sel(RR_A1_sel),
        .RR_A2_Address_sel(RR_A2_sel),
        .RR_A3_Address_sel(RR_A3_sel),
        .RR_Wr_En(RR_Wr_En),
        .EXE_ALU_Src(ALU_Src),
        .EXE_ALU_Oper(ALU_Oper),
        .Reg_D3_Sel(Reg_D3_Sel),
        .MEM_Wr_En(MEM_Wr_En),
        .pc_data_select(pc_data_sel)
    );

    

    assign control_signals = {RR_A3_sel, RR_Wr_En, ALU_Src,
                                  ALU_Oper, Reg_D3_Sel, MEM_Wr_En};

    // JAL: compute target in ID stage
    always @(*) begin
        if (ir_from_if_id[15:12] == 4'b1001) begin
            flush_from_id   = 1'b1;
            pc_ctrl_id      = 2'b01;
            pc_next_from_id = pc_next_from_if_id +
                              {{7{ir_from_if_id[8]}}, ir_from_if_id[8:0]};
        end else begin
            flush_from_id   = 1'b0;
            pc_ctrl_id      = 2'b00;
            pc_next_from_id = 16'd0;
        end
    end

    // =========================================================================
    // ID/RR PIPELINE REGISTER
    // =========================================================================
    wire id_rr_en  = pipe_en & ~instr_we;
    wire id_rr_rst = reset | flush_from_ex;


    ID2RR_Pipline_Reg id_rr_reg (
        .clk(clk), .rst(id_rr_rst), .enable(id_rr_en),
        .pc_in(pc_from_if_id), .pc_next_in(pc_next_from_if_id),
        .instr_in(ir_from_if_id), .cntrl_in(control_signals),
        .pc_out(pc_from_id_rr), .pc_next_out(pc_next_from_id_rr),
        .instr_out(ir_from_id_rr), .cntrl_out(ctrl_from_id_rr)
    );

    // =========================================================================
    // RR STAGE — Register Read
    // =========================================================================

    // Re-decode from ir_from_id_rr for correct alignment
    wire        RR_A1_sel_rr, RR_A2_sel_rr;
    wire [1:0]  RR_A3_sel_rr;
    wire        RR_Wr_En_rr, MEM_Wr_En_rr, pc_data_sel_rr;
    wire [1:0]  ALU_Src_rr, ALU_Oper_rr, Reg_D3_Sel_rr;
    wire [9:0]  ctrl_rr;

    control_decoder ctrl_dec_rr (
        .opcode(ir_from_id_rr[15:12]),
        .ir_lsb_2(ir_from_id_rr[1:0]),
        .RR_A1_Address_sel(RR_A1_sel_rr),
        .RR_A2_Address_sel(RR_A2_sel_rr),
        .RR_A3_Address_sel(RR_A3_sel_rr),
        .RR_Wr_En(RR_Wr_En_rr),
        .EXE_ALU_Src(ALU_Src_rr),
        .EXE_ALU_Oper(ALU_Oper_rr),
        .Reg_D3_Sel(Reg_D3_Sel_rr),
        .MEM_Wr_En(MEM_Wr_En_rr),
        .pc_data_select(pc_data_sel_rr)
    );

    assign ctrl_rr = {RR_A3_sel_rr, RR_Wr_En_rr, ALU_Src_rr,
                      ALU_Oper_rr, Reg_D3_Sel_rr, MEM_Wr_En_rr};

    // Address muxes
    // A1: 0=ir[11:9], 1=ir[8:6]
    mux_21 #(.IN_WIDTH(3),.OUT_WIDTH(3)) mux_a1 (
        .A(ir_from_id_rr[11:9]), .B(ir_from_id_rr[8:6]),
        .sel(RR_A1_sel_rr), .O(A1_addr)
    );
    // A2: 0=ir[5:3] (Rs2 for ADD/NDU/etc), 1=ir[8:6] (Rs2 for SW/BEQ)
    mux_21 #(.IN_WIDTH(3),.OUT_WIDTH(3)) mux_a2 (
        .A(ir_from_id_rr[5:3]), .B(ir_from_id_rr[8:6]),
        .sel(RR_A2_sel_rr), .O(A2_addr)
    );

    register_bank regfile (
        .clk(clk), .reset(reset),
        .readAddress1(A1_addr), .readAddress2(A2_addr),
        .writeAddress(rd_addr_at_wb), .writeData(rd_data_at_wb),
        .writeEnable(reg_wr_en_at_wb),
        .readData1(RF_D1), .readData2(RF_D2),
        .debug_addr(debug_reg_addr), .debug_data(debug_reg_data)
    );

    // =========================================================================
    // RR/EX PIPELINE REGISTER
    // =========================================================================
    wire [9:0]  ctrl_rr_to_ex = (nop_inject || flush_from_ex) ? 10'd0 : ctrl_rr;
    wire [15:0] ir_rr_to_ex   = (nop_inject || flush_from_ex) ? 16'b0111000000000000 : ir_from_id_rr;


    RR2EX_Pipline_Reg rr_ex_reg (
        .clk(clk), .rst(reset), .enable(~instr_we),
        .pc_in(pc_from_id_rr), .pc_next_in(pc_next_from_id_rr),
        .instr_in(ir_rr_to_ex), .cntrl_in(ctrl_rr_to_ex),


        .RF_D1_In(RF_D1), .RF_D2_In(RF_D2),
        .RF_A1_In(A1_addr), .RF_A2_In(A2_addr),
        .pc_out(pc_from_rr_ex), .pc_next_out(pc_next_from_rr_ex),
        .instr_out(ir_from_rr_ex), .cntrl_out(ctrl_from_rr_ex),
        .RF_D1_Out(RF_D1_from_rr_ex), .RF_D2_Out(RF_D2_from_rr_ex),
        .RF_A1_Out(A1_from_rr_ex), .RF_A2_Out(A2_from_rr_ex)
    );

    // =========================================================================
    // EX STAGE — ALU Execute
    // =========================================================================

    // ----------- DATA FORWARDING (EX/MM and MM/WB -> EX) -----------
    // ctrl_from_ex_mm[2] = RegWrite at MM stage
    wire ex_mm_rw = ctrl_from_ex_mm[2];
    wire fwd_a_mm = ex_mm_rw       && (rd_addr_ex_mm != 3'd0) && (rd_addr_ex_mm == A1_from_rr_ex);
    wire fwd_a_wb = reg_wr_en_at_wb && (rd_addr_at_wb != 3'd0) && (rd_addr_at_wb == A1_from_rr_ex);
    wire fwd_b_mm = ex_mm_rw       && (rd_addr_ex_mm != 3'd0) && (rd_addr_ex_mm == A2_from_rr_ex);
    wire fwd_b_wb = reg_wr_en_at_wb && (rd_addr_at_wb != 3'd0) && (rd_addr_at_wb == A2_from_rr_ex);

    // Use post-mem value (rd_out_at_mem) so LW->dependent forwards loaded data,
    // not the address ALU result that sits in rd_data_ex_mm.
    wire [15:0] fwd_d1 = fwd_a_mm ? rd_out_at_mem
                       : fwd_a_wb ? rd_data_at_wb
                       : RF_D1_from_rr_ex;
    wire [15:0] fwd_d2 = fwd_b_mm ? rd_out_at_mem
                       : fwd_b_wb ? rd_data_at_wb
                       : RF_D2_from_rr_ex;

    // ALU source A = forwarded RF_D1, source B = forwarded RF_D2 or imm6
    assign alu_src_A = fwd_d1;
    assign imm6      = {{10{ir_from_rr_ex[5]}}, ir_from_rr_ex[5:0]};
    assign lhi_data  = {ir_from_rr_ex[8:0], 7'b0};

    mux_41 #(.IN_WIDTH(16),.OUT_WIDTH(16)) alu_srcb_mux (
        .A(fwd_d2), .B(imm6), .C(lhi_data), .D(16'd0),
        .sel(ctrl_from_rr_ex[6:5]), .O(alu_src_B)
    );

    // ALU control — handles ADC/ADZ gating and flag writes
    alu_ctrl actl (
        .instr(ir_from_rr_ex),
        .carry_in(carry_flag_out), .zero_in(zero_flag_out),
        .reg_write_enable_in(ctrl_from_rr_ex[7]),
        .carry_write_en(carry_write_en), .zero_write_en(zero_write_en),
        .reg_write_enable_out(reg_wr_en_final),
        .alu_operation_out(alu_op_final)
    );

    alu alu_exec (
        .a(alu_src_A), .b(alu_src_B),
        .alu_control(alu_op_final),
        .result(alu_out), .zero(zero_flag_in), .carry(carry_flag_in)
    );

    // Carry and zero flag registers
    register_n #(.N(1)) carry_reg (
        .clk(clk), .reset(reset), .enable(carry_write_en),
        .in(carry_flag_in), .out(carry_flag_out)
    );

    always @(*) begin
        if (zero_write_en)
            zero_flag_mem = zero_flag_in;
        else if (zero_wr_en_from_mem)
            zero_flag_mem = 1'b1;
        else
            zero_flag_mem = zero_flag_out;
    end

    register_n #(.N(1)) zero_reg (
        .clk(clk), .reset(reset),
        .enable(zero_write_en | zero_wr_en_from_mem),
        .in(zero_flag_mem), .out(zero_flag_out)
    );

    assign zero_flag_port  = zero_flag_out;
    assign carry_flag_port = carry_flag_out;
    wire pc_data_sel_ex = (ir_from_rr_ex[15:12] == 4'b1001) ||
                             (ir_from_rr_ex[15:12] == 4'b1011);


    // RD address select mux: {A3_sel} picks ir[5:3], ir[8:6], or ir[11:9]
    // RD addr: 00=ir[11:9] (ADD/NDU), 01=ir[8:6] (LW), 10=ir[11:9] (ADI/LHI/JAL)
    mux_41 #(.IN_WIDTH(3),.OUT_WIDTH(3)) rd_addr_mux (
        .A(ir_from_rr_ex[11:9]), .B(ir_from_rr_ex[8:6]),
        .C(ir_from_rr_ex[11:9]), .D(3'd0),
        .sel(ctrl_from_rr_ex[9:8]), .O(rd_addr_at_ex)
    );

    // RD data: ALU result, LHI, or PC+1 (for JAL)

wire [15:0] rd_data_alu_or_lhi;

// LHI uses immediate upper load, others use ALU output
assign rd_data_alu_or_lhi =
       (ir_from_rr_ex[15:12] == 4'b0011) ? lhi_data :
                                           alu_out;

// JAL/JRI write PC+1, others write ALU/LHI result
mux_21 #(.IN_WIDTH(16), .OUT_WIDTH(16)) pc_data_mux (
    .A(rd_data_alu_or_lhi),
    .B(pc_next_from_rr_ex),
    .sel(pc_data_sel_ex),
    .O(rd_data_at_ex)
);

    // BEQ and JRI handled in EX stage
    assign pc_branch = pc_next_from_rr_ex +
                       {{10{ir_from_rr_ex[5]}}, ir_from_rr_ex[5:0]};

    always @(*) begin
        flush_from_ex   = 1'b0;
        pc_ctrl_ex      = 2'b00;
        pc_next_from_ex = 16'd0;

        if (ir_from_rr_ex[15:12] == 4'b1000) begin  // BEQ
            if (fwd_d1 == fwd_d2) begin
                flush_from_ex   = 1'b1;
                pc_ctrl_ex      = 2'b10;
                pc_next_from_ex = pc_branch;
            end
        end else if (ir_from_rr_ex[15:12] == 4'b1011) begin  // JRI
            flush_from_ex   = 1'b1;
            pc_ctrl_ex      = 2'b10;
            pc_next_from_ex = fwd_d1 +
                              {{7{ir_from_rr_ex[8]}}, ir_from_rr_ex[8:0]};
        end
    end

    // NOP inject for EX stage on load-use
    assign new_ctrl_ex = {reg_wr_en_final, ctrl_from_rr_ex[1], ctrl_from_rr_ex[0]};


    
    // EX/MM PIPELINE REGISTER
    
    EX2MEM_Pipline_Reg ex_mm_reg (
        .clk(clk), .rst(reset), .enable(~instr_we),
        .Control_In(new_ctrl_ex),
        .Rd_Addr_In_From_Ex(rd_addr_at_ex),
        .Rd_Data_In_From_Ex(rd_data_at_ex),
        .RF_D2_In(fwd_d2),
        .ALU_Result_In(alu_out),
        .Instr_In(ir_from_rr_ex),
        .Control_Out(ctrl_from_ex_mm),
        .Rd_Addr_Out_PR(rd_addr_ex_mm),
        .Rd_Data_Out_PR(rd_data_ex_mm),
        .RF_D2_Out(RF_D2_from_ex_mm),
        .ALU_Result_Out(alu_from_ex_mm),
        .Instr_Out(ir_from_ex_mm)
    );

    
    // MM STAGE — Memory Access
    data_memory dmem (
        .clk(clk), .rst(reset),
        .mem_access_addr(alu_from_ex_mm),
        .mem_write_data(RF_D2_from_ex_mm),
        .mem_write_en(ctrl_from_ex_mm[0]),
        .mem_read_data(mem_out),
        .debug_addr(debug_mem_addr),
        .debug_data(debug_mem_data)
    );

    // Select between ALU result and memory output
    mux_21 #(.IN_WIDTH(16),.OUT_WIDTH(16)) mem_out_mux (
        .A(rd_data_ex_mm), .B(mem_out),
        .sel(ctrl_from_ex_mm[1]), .O(rd_out_at_mem)
    );

    // Zero flag from LW zero result
    assign zero_wr_en_from_mem = (ir_from_ex_mm[15:12] == 4'b0100) &&
                                  (mem_out == 16'd0);



    // MM/WB PIPELINE REGISTER
    
  MEM2WB_Pipline_Reg mm_wb_reg (
    .clk(clk), .rst(reset), .enable(~instr_we),

    // NEW: connect RegWrite
    .RegWrite_In(ctrl_from_ex_mm[2]),   // assuming bit [2] is RR_Wr_En
    .RegWrite_Out(reg_wr_en_at_wb),

    // keep the rest as before
    .Rd_Addr_In_From_Mem(rd_addr_ex_mm),
    .Rd_Data_In_From_Mem(rd_out_at_mem),
    .Instr_In(ir_from_ex_mm),
    .Rd_Addr_Out_PR(rd_addr_at_wb),
    .Rd_Data_Out_PR(rd_data_at_wb),
    .Instr_Out(ir_at_wb)
);

    // HAZARD DETECTION — Load-use stall only
    
    assign load_use_hazard = (ir_from_rr_ex[15:12] == 4'b0100) &&
                             ((A1_addr == rd_addr_at_ex) ||
                              (A2_addr == rd_addr_at_ex));

    always @(posedge clk) begin
        if (reset)
            stall_pending <= 1'b0;
        else if (load_use_hazard && !stall_pending)
            stall_pending <= 1'b1;
        else
            stall_pending <= 1'b0;
    end

    // stall: freeze PC, IF/ID, ID/RR for one cycle
    assign pipe_en    = ~(load_use_hazard & ~stall_pending);
    assign nop_inject =   load_use_hazard & ~stall_pending;

    
endmodule


