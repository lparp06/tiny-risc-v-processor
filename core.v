module core #(
    parameter CORE_ID = 0
)(
    input clk,
    input rst,

    // ------------------------------------------------------------
    // FSM enable
    // ------------------------------------------------------------
    // This is a slow-step enable from the top level.
    // When fsm_en is 1 for one clock cycle, the core advances one FSM state.
    input fsm_en,

    // ------------------------------------------------------------
    // Debug register mode
    // ------------------------------------------------------------
    // When debug_reg_mode is high, read port 0 of the register file
    // reads debug_reg_addr instead of rs1.
    //
    // The top level should pause the core when debug_reg_mode is high.
    input debug_reg_mode,

    // ------------------------------------------------------------
    // Private instruction memory interface
    // ------------------------------------------------------------
    // Each core has its own instruction memory.
    // The core outputs a byte address, and imemory.v converts addr[11:2]
    // into the actual word address.
    output [31:0] imem_addr,
    input  [31:0] imem_rdata,

    // ------------------------------------------------------------
    // Shared data memory interface
    // ------------------------------------------------------------
    // These signals go to the arbiter in tinyrv_parallel.v.
    //
    // dmem_req:
    //   This core is requesting access to shared data memory.
    //
    // dmem_gnt:
    //   The arbiter has granted this core access.
    //
    // dmem_wen:
    //   This core is performing a store.
    //
    // dmem_addr:
    //   Address for load/store.
    //
    // dmem_wdata:
    //   Store data.
    //
    // dmem_rdata:
    //   Load data from shared memory.
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output        dmem_wen,
    output        dmem_req,
    input  [31:0] dmem_rdata,
    input         dmem_gnt,

    // ------------------------------------------------------------
    // Debug outputs
    // ------------------------------------------------------------
    input  [4:0]  debug_reg_addr,
    output [31:0] debug_reg_data,
    output [31:0] debug_pc,
    output [31:0] debug_inst,
    output [2:0]  debug_state
);

// ============================================================
// Local parameters
// ============================================================

// Writeback source select
localparam WB_ALU = 2'd0;  // write ALU result
localparam WB_MEM = 2'd1;  // write loaded data
localparam WB_PC4 = 2'd2;  // write PC + 4, used by jumps
localparam WB_IMM = 2'd3;  // write immediate, used by LUI-style behavior

// Immediate format select
localparam IMM_I = 3'd0;
localparam IMM_S = 3'd1;
localparam IMM_B = 3'd2;
localparam IMM_U = 3'd3;
localparam IMM_J = 3'd4;

// Branch type select
localparam BR_BEQ  = 3'd0;
localparam BR_BNE  = 3'd1;
localparam BR_BLT  = 3'd2;
localparam BR_BGE  = 3'd3;
localparam BR_BLTU = 3'd4;
localparam BR_BGEU = 3'd5;

// Multicycle FSM states
localparam S_FETCH_ADDR  = 3'd0;  // present PC to instruction memory
localparam S_FETCH_LATCH = 3'd1;  // latch instruction memory output
localparam S_DECODE      = 3'd2;  // decode instruction
localparam S_EXEC        = 3'd3;  // execute ALU / branch / address calc
localparam S_MEM         = 3'd4;  // request shared data memory
localparam S_MEM_LATCH   = 3'd5;  // latch stable load data
localparam S_WB          = 3'd6;  // write result back to register file

// ============================================================
// FSM state register
// ============================================================
// S is the current FSM state.
// NS is the next FSM state.
//
// The FSM only advances when fsm_en is high. This allows the
// top level to slow the CPU down for visible board debugging.

reg [2:0] S;
reg [2:0] NS;

always @(posedge clk or negedge rst) begin
    if (!rst)
        S <= S_FETCH_ADDR;
    else if (fsm_en)
        S <= NS;
end

// ============================================================
// Program counter
// ============================================================
// The PC updates only when pc_en is high.
// This is important: the PC should not advance every clock cycle.
// It should only update when the current instruction is complete.

wire [31:0] pc;
wire [31:0] pc_next;
wire        pc_en;

pc u_pc (
    .clk     (clk),
    .rst     (rst),
    .en      (pc_en),
    .pc_next (pc_next),
    .pc      (pc)
);

// The instruction memory address is simply the current PC.
assign imem_addr = pc;

// ============================================================
// Instruction register and instruction PC
// ============================================================
// inst_reg holds the instruction currently being executed.
// inst_pc holds the PC of that instruction.
//
// The core uses two fetch states:
//   S_FETCH_ADDR  : put PC on imem_addr
//   S_FETCH_LATCH : latch imem_rdata into inst_reg

reg [31:0] inst_reg;
reg [31:0] inst_pc;

always @(posedge clk or negedge rst) begin
    if (!rst)
        inst_pc <= 32'd0;
    else if (fsm_en && (S == S_FETCH_ADDR))
        inst_pc <= pc;
end

always @(posedge clk or negedge rst) begin
    if (!rst)
        inst_reg <= 32'd0;
    else if (fsm_en && (S == S_FETCH_LATCH))
        inst_reg <= imem_rdata;
end

// ============================================================
// Decode
// ============================================================
// decode.v breaks the instruction into fields and immediate values.

wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [6:0] funct7;

wire [31:0] imm_i;
wire [31:0] imm_s;
wire [31:0] imm_b;
wire [31:0] imm_u;
wire [31:0] imm_j;

decode u_decode (
    .inst   (inst_reg),
    .opcode (opcode),
    .rd     (rd),
    .funct3 (funct3),
    .rs1    (rs1),
    .rs2    (rs2),
    .funct7 (funct7),
    .imm_i  (imm_i),
    .imm_s  (imm_s),
    .imm_b  (imm_b),
    .imm_u  (imm_u),
    .imm_j  (imm_j)
);

// ============================================================
// Control
// ============================================================
// control.v looks at opcode/funct fields and generates the control
// signals for the datapath.

wire       reg_wen;
wire       alu_src_imm;
wire       alu_src_pc;
wire [3:0] alu_op;
wire       mem_wen;
wire [1:0] wb_sel;
wire [2:0] imm_sel;
wire       branch;
wire [2:0] branch_type;
wire       jump;
wire       jump_reg;

control u_control (
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7      (funct7),
    .reg_wen     (reg_wen),
    .alu_src_imm (alu_src_imm),
    .alu_src_pc  (alu_src_pc),
    .alu_op      (alu_op),
    .mem_wen     (mem_wen),
    .wb_sel      (wb_sel),
    .imm_sel     (imm_sel),
    .branch      (branch),
    .branch_type (branch_type),
    .jump        (jump),
    .jump_reg    (jump_reg)
);

// ============================================================
// Register file
// ============================================================
// Each core has its own private register file.
//
// rf_rd0 normally reads rs1.
// rf_rd1 reads rs2.
// In debug mode, rf_rd0 reads debug_reg_addr so the board can
// display any selected register.

wire [4:0]  rf_ra0;
wire [31:0] rf_rd0;
wire [31:0] rf_rd1;
wire        rf_wen;
wire [4:0]  rf_waddr;
wire [31:0] rf_wdata;

assign rf_ra0 = debug_reg_mode ? debug_reg_addr : rs1;

// Register writeback happens only in S_WB.
// Stores and branches do not use S_WB, so they do not write registers.
assign rf_wen   = reg_wen && fsm_en && (S == S_WB);
assign rf_waddr = rd;

regfile u_regfile (
    .clk   (clk),
    .rst   (rst),
    .ra0   (rf_ra0),
    .ra1   (rs2),
    .rd0   (rf_rd0),
    .rd1   (rf_rd1),
    .waddr (rf_waddr),
    .wdata (rf_wdata),
    .wen   (rf_wen)
);

// Debug register output comes from read port 0.
assign debug_reg_data = rf_rd0;

// ============================================================
// Immediate select mux
// ============================================================
// The decode module gives all immediate types.
// The control unit selects which one this instruction needs.

reg [31:0] imm_selected;

always @(*) begin
    case (imm_sel)
        IMM_I:   imm_selected = imm_i;
        IMM_S:   imm_selected = imm_s;
        IMM_B:   imm_selected = imm_b;
        IMM_U:   imm_selected = imm_u;
        IMM_J:   imm_selected = imm_j;
        default: imm_selected = imm_i;
    endcase
end

// ============================================================
// ALU input muxes and ALU
// ============================================================
// ALU input A can be rs1 or the instruction PC.
// ALU input B can be rs2 or the selected immediate.

wire [31:0] alu_a;
wire [31:0] alu_b;
wire [31:0] alu_out;

assign alu_a = alu_src_pc  ? inst_pc      : rf_rd0;
assign alu_b = alu_src_imm ? imm_selected : rf_rd1;

alu u_alu (
    .a   (alu_a),
    .b   (alu_b),
    .op  (alu_op),
    .out (alu_out)
);

// ============================================================
// Branch compare
// ============================================================
// branch_taken decides whether a branch should use branch_target.

wire branch_taken;

assign branch_taken =
    branch && (
        ((branch_type == BR_BEQ)  && (rf_rd0 == rf_rd1)) ||
        ((branch_type == BR_BNE)  && (rf_rd0 != rf_rd1)) ||
        ((branch_type == BR_BLT)  && ($signed(rf_rd0) <  $signed(rf_rd1))) ||
        ((branch_type == BR_BGE)  && ($signed(rf_rd0) >= $signed(rf_rd1))) ||
        ((branch_type == BR_BLTU) && (rf_rd0 <  rf_rd1)) ||
        ((branch_type == BR_BGEU) && (rf_rd0 >= rf_rd1))
    );

// ============================================================
// PC / next-PC logic
// ============================================================
// PC is updated when the current instruction has completed.
//
// Branches complete in S_EXEC.
// Stores complete in S_MEM after data memory grant.
// Loads now complete in S_WB after S_MEM_LATCH.
// Most other instructions complete in S_WB.

wire [31:0] pc_plus4;
wire [31:0] inst_pc_plus4;
wire [31:0] branch_target;
wire [31:0] jal_target;
wire [31:0] jalr_target;

wire        pc_update_exec;
wire        pc_update_mem;
wire        pc_update_wb;

assign pc_plus4      = inst_pc + 32'd4;
assign inst_pc_plus4 = inst_pc + 32'd4;

assign branch_target = inst_pc + imm_b;
assign jal_target    = inst_pc + imm_j;
assign jalr_target   = (rf_rd0 + imm_i) & 32'hFFFF_FFFE;

assign pc_update_exec = (S == S_EXEC) && branch;

// Store instruction completes in S_MEM.
// It should only advance the PC after this core receives dmem_gnt.
assign pc_update_mem = (S == S_MEM) && mem_wen && dmem_gnt;

// ALU, load, jump, LUI/AUIPC-style instructions complete in S_WB.
assign pc_update_wb = (S == S_WB);

assign pc_en = fsm_en && (pc_update_exec || pc_update_mem || pc_update_wb);

assign pc_next =
    ((S == S_EXEC) && branch_taken) ? branch_target :
    ((S == S_EXEC) && branch)       ? pc_plus4      :
    ((S == S_WB)   && jump_reg)     ? jalr_target   :
    ((S == S_WB)   && jump)         ? jal_target    :
                                      pc_plus4;

// ============================================================
// Shared data memory interface
// ============================================================
// This is the important part for the two-core design.
//
// The core must hold dmem_req high for the whole time it needs the
// shared data memory. For loads, that now includes S_MEM_LATCH.
//
// Do NOT gate dmem_req with fsm_en.
//
// Why:
//   fsm_en is only a one-clock pulse when using the slow divider.
//   If dmem_req were gated by fsm_en, the arbiter would only see the
//   request for one clock. The memory address would disappear before
//   the load data was captured.

wire is_load;
wire is_store;
wire is_mem_op;

assign is_store  = mem_wen;
assign is_load   = (wb_sel == WB_MEM);
assign is_mem_op = is_store || is_load;

// Keep request high during S_MEM.
// For loads, also keep it high during S_MEM_LATCH so the top-level
// memory mux keeps pointing at this core while dmem_rdata settles.
assign dmem_req =
    ((S == S_MEM) || ((S == S_MEM_LATCH) && is_load)) && is_mem_op;

// Store writes only once, in S_MEM, after grant.
assign dmem_wen = (S == S_MEM) && is_store && dmem_gnt;

assign dmem_addr  = alu_out;
assign dmem_wdata = rf_rd1;

// ============================================================
// Load data latch
// ============================================================
// Loads have three phases now:
//   S_MEM       : request/grant shared memory
//   S_MEM_LATCH : capture stable dmem_rdata
//   S_WB        : write load_data_reg into rd
//
// This fixes the issue where x7 was staying 0 because dmem_rdata
// was being captured too early or after the top-level mux changed.

reg [31:0] load_data_reg;

always @(posedge clk or negedge rst) begin
    if (!rst)
        load_data_reg <= 32'd0;
    else if (fsm_en && (S == S_MEM_LATCH) && is_load)
        load_data_reg <= dmem_rdata;
end

// ============================================================
// FSM next-state logic
// ============================================================
// This determines the instruction flow.
//
// Important memory behavior:
//   Store: S_EXEC -> S_MEM -> S_FETCH_ADDR
//   Load : S_EXEC -> S_MEM -> S_MEM_LATCH -> S_WB

always @(*) begin
    NS = S;

    case (S)
        S_FETCH_ADDR: begin
            NS = S_FETCH_LATCH;
        end

        S_FETCH_LATCH: begin
            NS = S_DECODE;
        end

        S_DECODE: begin
            NS = S_EXEC;
        end

        S_EXEC: begin
            if (branch)
                NS = S_FETCH_ADDR;
            else if (mem_wen)
                NS = S_MEM;        // store
            else if (wb_sel == WB_MEM)
                NS = S_MEM;        // load
            else
                NS = S_WB;
        end

        S_MEM: begin
            if (!dmem_gnt)
                NS = S_MEM;
            else if (mem_wen)
                NS = S_FETCH_ADDR; // store complete
            else
                NS = S_MEM_LATCH;  // load gets one extra FSM step
        end

        S_MEM_LATCH: begin
            NS = S_WB;             // load data has been latched
        end

        S_WB: begin
            NS = S_FETCH_ADDR;
        end

        default: begin
            NS = S_FETCH_ADDR;
        end
    endcase
end

// ============================================================
// Writeback mux
// ============================================================
// Selects what data is written into rd during S_WB.
//
// For loads, use load_data_reg, not dmem_rdata directly.

assign rf_wdata =
    (wb_sel == WB_MEM) ? load_data_reg :
    (wb_sel == WB_PC4) ? inst_pc_plus4 :
    (wb_sel == WB_IMM) ? imm_selected  :
                         alu_out;

// ============================================================
// Debug / status outputs
// ============================================================

assign debug_pc    = pc;
assign debug_inst  = inst_reg;
assign debug_state = S;

endmodule