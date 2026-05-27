module tinyrv_parallel
(
    input         CLOCK_50,
    input  [9:0] SW,
    input  [3:0] KEY,
    output [9:0] LEDR,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);

// ============================================================
// Board clock/reset
// ============================================================

wire clk;
wire rst;

assign clk = CLOCK_50;
assign rst = KEY[3];       // active-low reset from KEY[3]

// ============================================================
// Switch map
// ============================================================
//
// SW[9]   debug register inspect mode
//         0 = normal display
//         1 = inspect selected register, cores paused
//
// SW[8]   normal display select
//         0 = show PC
//         1 = show current/latched instruction
//
// SW[7]   data-memory tester mode
//         0 = normal two-core CPU mode
//         1 = pause cores and let dmem_tester own shared dmem
//
// SW[6]   core display select
//         0 = display/debug core 0
//         1 = display/debug core 1
//
// SW[5]   program select
//         0 = unlocked/no-lock race program
//         1 = locked/Peterson program
//
// SW[4:0] register select in debug mode
//         Note: SW[5] is NOT part of register select because register
//         select only uses SW[4:0].

wire       debug_reg_mode;
wire       normal_inst_display;
wire       memtest_mode;
wire       debug_core_sel;
wire       program_sel;
wire [4:0] debug_reg_addr;
wire       cpu_run_mode;

assign debug_reg_mode      = SW[9];
assign normal_inst_display = SW[8];
assign memtest_mode        = SW[7];
assign debug_core_sel      = SW[6];
assign program_sel         = SW[5];
assign debug_reg_addr      = SW[4:0];

assign cpu_run_mode = !memtest_mode && !debug_reg_mode;

// ============================================================
// Slow enable generator
// ============================================================
// Set USE_SLOW_EN = 1 for visible step-by-step debugging.
// Set USE_SLOW_EN = 0 for full-speed running.

localparam USE_SLOW_EN = 1'b0;

reg  [25:0] slow_count;
wire        slow_tick;
wire        slow_en;

always @(posedge clk or negedge rst) begin
    if (!rst)
        slow_count <= 26'd0;
    else if (slow_count == 26'd4_999_999)
        slow_count <= 26'd0;
    else
        slow_count <= slow_count + 26'd1;
end

assign slow_tick = (slow_count == 26'd4_999_999);
assign slow_en   = USE_SLOW_EN ? slow_tick : 1'b1;

// This is the enable actually sent to each core.
wire fsm_en;
assign fsm_en = slow_en && cpu_run_mode;

// ============================================================
// Core enables
// ============================================================

wire core0_en;
wire core1_en;

assign core0_en = fsm_en;
assign core1_en = fsm_en;

// ============================================================
// Core 0 wires
// ============================================================

wire [31:0] core0_imem_addr;
wire [31:0] core0_imem_rdata;

wire        core0_dmem_req;
wire        core0_dmem_wen;
wire [31:0] core0_dmem_addr;
wire [31:0] core0_dmem_wdata;
wire [31:0] core0_dmem_rdata;
wire        core0_dmem_gnt;

wire [31:0] core0_debug_reg_data;
wire [31:0] core0_debug_pc;
wire [31:0] core0_debug_inst;
wire [2:0]  core0_debug_state;

// ============================================================
// Core 1 wires
// ============================================================

wire [31:0] core1_imem_addr;
wire [31:0] core1_imem_rdata;

wire        core1_dmem_req;
wire        core1_dmem_wen;
wire [31:0] core1_dmem_addr;
wire [31:0] core1_dmem_wdata;
wire [31:0] core1_dmem_rdata;
wire        core1_dmem_gnt;

wire [31:0] core1_debug_reg_data;
wire [31:0] core1_debug_pc;
wire [31:0] core1_debug_inst;
wire [2:0]  core1_debug_state;

// ============================================================
// Core instances
// ============================================================

core #(
    .CORE_ID (0)
) u_core0 (
    .clk             (clk),
    .rst             (rst),
    .fsm_en          (core0_en),

    .debug_reg_mode  (debug_reg_mode && !debug_core_sel),
    .debug_reg_addr  (debug_reg_addr),
    .debug_reg_data  (core0_debug_reg_data),

    .imem_addr       (core0_imem_addr),
    .imem_rdata      (core0_imem_rdata),

    .dmem_req        (core0_dmem_req),
    .dmem_wen        (core0_dmem_wen),
    .dmem_addr       (core0_dmem_addr),
    .dmem_wdata      (core0_dmem_wdata),
    .dmem_rdata      (core0_dmem_rdata),
    .dmem_gnt        (core0_dmem_gnt),

    .debug_pc        (core0_debug_pc),
    .debug_inst      (core0_debug_inst),
    .debug_state     (core0_debug_state)
);

core #(
    .CORE_ID (1)
) u_core1 (
    .clk             (clk),
    .rst             (rst),
    .fsm_en          (core1_en),

    .debug_reg_mode  (debug_reg_mode && debug_core_sel),
    .debug_reg_addr  (debug_reg_addr),
    .debug_reg_data  (core1_debug_reg_data),

    .imem_addr       (core1_imem_addr),
    .imem_rdata      (core1_imem_rdata),

    .dmem_req        (core1_dmem_req),
    .dmem_wen        (core1_dmem_wen),
    .dmem_addr       (core1_dmem_addr),
    .dmem_wdata      (core1_dmem_wdata),
    .dmem_rdata      (core1_dmem_rdata),
    .dmem_gnt        (core1_dmem_gnt),

    .debug_pc        (core1_debug_pc),
    .debug_inst      (core1_debug_inst),
    .debug_state     (core1_debug_state)
);

// ============================================================
// Private instruction memories with program-select mux
// ============================================================
//
// Each core has two private instruction memories:
//
//   Core 0 unlocked/no-lock memory
//   Core 0 locked/Peterson memory
//   Core 1 unlocked/no-lock memory
//   Core 1 locked/Peterson memory
//
// SW[5] chooses which pair feeds the cores.
//
// IMPORTANT:
// Change SW[5] while reset is held, then release reset.
// Do not switch SW[5] while the program is already running.

wire [31:0] core0_imem_rdata_unlocked;
wire [31:0] core0_imem_rdata_locked;
wire [31:0] core1_imem_rdata_unlocked;
wire [31:0] core1_imem_rdata_locked;

// Core 0 unlocked/no-lock instruction memory.
// Wrapper should point to core0unlocked IP / MIF.
imemory_core0_unlocked u_core0_imem_unlocked (
    .addr  (core0_imem_addr),
    .clk   (clk),
    .rdata (core0_imem_rdata_unlocked)
);

// Core 0 locked/Peterson instruction memory.
// Wrapper should point to core0locked IP / MIF.
imemory_core0_locked u_core0_imem_locked (
    .addr  (core0_imem_addr),
    .clk   (clk),
    .rdata (core0_imem_rdata_locked)
);

// Core 1 unlocked/no-lock instruction memory.
// Wrapper should point to core1unlocked IP / MIF.
imemory_core1_unlocked u_core1_imem_unlocked (
    .addr  (core1_imem_addr),
    .clk   (clk),
    .rdata (core1_imem_rdata_unlocked)
);

// Core 1 locked/Peterson instruction memory.
// Wrapper should point to core1locked IP / MIF.
imemory_core1_locked u_core1_imem_locked (
    .addr  (core1_imem_addr),
    .clk   (clk),
    .rdata (core1_imem_rdata_locked)
);

// Program-select mux.
// SW[5] = 0: unlocked/no-lock race demo.
// SW[5] = 1: locked/Peterson demo.
assign core0_imem_rdata = program_sel ? core0_imem_rdata_locked
                                      : core0_imem_rdata_unlocked;

assign core1_imem_rdata = program_sel ? core1_imem_rdata_locked
                                      : core1_imem_rdata_unlocked;

// ============================================================
// Shared data memory arbiter
// ============================================================
// One shared data memory.
// If both cores request at the same time, arb_turn chooses the winner.
// The losing core stays in S_MEM until it receives dmem_gnt.

reg arb_turn;

always @(posedge clk or negedge rst) begin
    if (!rst)
        arb_turn <= 1'b0;
    else if (fsm_en && core0_dmem_req && core1_dmem_req)
        arb_turn <= ~arb_turn;
end

wire arb_grant0;
wire arb_grant1;

assign arb_grant0 =
    !memtest_mode &&
    core0_dmem_req &&
    (!core1_dmem_req || (arb_turn == 1'b0));

assign arb_grant1 =
    !memtest_mode &&
    core1_dmem_req &&
    (!core0_dmem_req || (arb_turn == 1'b1));

assign core0_dmem_gnt = arb_grant0;
assign core1_dmem_gnt = arb_grant1;

// Both cores see the same shared memory read data.
// Only the granted core should use it.
assign core0_dmem_rdata = shared_dmem_rdata;
assign core1_dmem_rdata = shared_dmem_rdata;

// ============================================================
// Latched arbiter event flags
// ============================================================
// These make it easy to prove that both cores requested and were granted.
// They reset when KEY[3] is pressed.

reg saw_core0_req;
reg saw_core1_req;
reg saw_both_req;
reg saw_core0_gnt;
reg saw_core1_gnt;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        saw_core0_req <= 1'b0;
        saw_core1_req <= 1'b0;
        saw_both_req  <= 1'b0;
        saw_core0_gnt <= 1'b0;
        saw_core1_gnt <= 1'b0;
    end
    else begin
        if (core0_dmem_req)
            saw_core0_req <= 1'b1;

        if (core1_dmem_req)
            saw_core1_req <= 1'b1;

        if (core0_dmem_req && core1_dmem_req)
            saw_both_req <= 1'b1;

        if (arb_grant0)
            saw_core0_gnt <= 1'b1;

        if (arb_grant1)
            saw_core1_gnt <= 1'b1;
    end
end

// ============================================================
// Data memory tester
// ============================================================
// When SW[7] = 1, both cores are paused and this tester owns dmem.
// It overwrites dmem, so reset the CPU after using it.

wire [31:0] shared_dmem_rdata;

wire [31:0] mt_addr;
wire [31:0] mt_wdata;
wire        mt_wen;
wire        mt_done;
wire        mt_error;
wire [9:0]  mt_index;
wire [9:0]  mt_error_index;
wire [31:0] mt_expected;
wire [31:0] mt_observed;

dmem_tester #(
    .ADDR_BITS (10),
    .DEPTH     (1024)
) u_dmem_tester (
    .clk         (clk),
    .rst         (rst),
    .start       (memtest_mode),

    .addr        (mt_addr),
    .wdata       (mt_wdata),
    .wen         (mt_wen),
    .rdata       (shared_dmem_rdata),

    .done        (mt_done),
    .error       (mt_error),
    .index       (mt_index),
    .error_index (mt_error_index),
    .expected    (mt_expected),
    .observed    (mt_observed)
);

// ============================================================
// Shared data memory mux
// ============================================================
// Priority:
//   1. dmem_tester when SW[7] = 1
//   2. core 1 if granted
//   3. core 0 if granted
//   4. idle

reg [31:0] shared_dmem_addr;
reg [31:0] shared_dmem_wdata;
reg        shared_dmem_wen;

always @(*) begin
    if (memtest_mode) begin
        shared_dmem_addr  = mt_addr;
        shared_dmem_wdata = mt_wdata;
        shared_dmem_wen   = mt_wen;
    end
    else if (arb_grant1) begin
        shared_dmem_addr  = core1_dmem_addr;
        shared_dmem_wdata = core1_dmem_wdata;
        shared_dmem_wen   = core1_dmem_wen;
    end
    else if (arb_grant0) begin
        shared_dmem_addr  = core0_dmem_addr;
        shared_dmem_wdata = core0_dmem_wdata;
        shared_dmem_wen   = core0_dmem_wen;
    end
    else begin
        shared_dmem_addr  = 32'd0;
        shared_dmem_wdata = 32'd0;
        shared_dmem_wen   = 1'b0;
    end
end

dmemory u_shared_dmem (
    .clk   (clk),
    .addr  (shared_dmem_addr),
    .wdata (shared_dmem_wdata),
    .wen   (shared_dmem_wen),
    .rdata (shared_dmem_rdata)
);

// ============================================================
// Display mux
// ============================================================

wire [31:0] selected_pc;
wire [31:0] selected_inst;
wire [31:0] selected_reg_data;

assign selected_pc       = debug_core_sel ? core1_debug_pc       : core0_debug_pc;
assign selected_inst     = debug_core_sel ? core1_debug_inst     : core0_debug_inst;
assign selected_reg_data = debug_core_sel ? core1_debug_reg_data : core0_debug_reg_data;

reg [31:0] display;

always @(*) begin
    if (debug_reg_mode) begin
        // Register inspect mode.
        display = selected_reg_data;
    end
    else if (memtest_mode) begin
        // Data memory tester display.
        if (mt_error)
            display = {14'd0, mt_error_index, 8'hEE}; // failed index + EE marker
        else if (mt_done)
            display = 32'h000001;                     // PASS
        else
            display = {22'd0, mt_index};              // progress index 000..3FF
    end
    else begin
        // Normal CPU display.
        display = normal_inst_display ? selected_inst : selected_pc;
    end
end

// ============================================================
// LED display
// ============================================================
//
// Debug mode:
//   LEDR[9]   = debug mode
//   LEDR[8]   = selected core
//   LEDR[4:0] = selected register
//
// Memtest mode:
//   LEDR[9] = memtest active
//   LEDR[8] = done
//   LEDR[7] = error
//   LEDR[6] = running
//   LEDR[5:0] = low bits of mt_index
//
// Normal CPU mode:
//   LEDR[9] = CPU running
//   LEDR[8] = program select, 0 unlocked / 1 locked
//   LEDR[7] = selected display core
//   LEDR[6] = saw both cores request memory at same time
//   LEDR[5] = saw core 1 grant
//   LEDR[4] = saw core 0 grant
//   LEDR[3] = live core 1 request
//   LEDR[2] = live core 0 request
//   LEDR[1] = live core 1 grant
//   LEDR[0] = live core 0 grant

reg [9:0] ledr_display;

always @(*) begin
    ledr_display = 10'd0;

    if (debug_reg_mode) begin
        ledr_display[9]   = 1'b1;
        ledr_display[8]   = debug_core_sel;
        ledr_display[4:0] = debug_reg_addr;
    end
    else if (memtest_mode) begin
        ledr_display[9]   = 1'b1;
        ledr_display[8]   = mt_done;
        ledr_display[7]   = mt_error;
        ledr_display[6]   = !mt_done;
        ledr_display[5:0] = mt_index[5:0];
    end
    else begin
        ledr_display[9] = cpu_run_mode;
        ledr_display[8] = program_sel;
        ledr_display[7] = debug_core_sel;

        ledr_display[6] = saw_both_req;
        ledr_display[5] = saw_core1_gnt;
        ledr_display[4] = saw_core0_gnt;

        ledr_display[3] = core1_dmem_req;
        ledr_display[2] = core0_dmem_req;
        ledr_display[1] = arb_grant1;
        ledr_display[0] = arb_grant0;
    end
end

assign LEDR = ledr_display;

// ============================================================
// HEX display
// ============================================================

hex7seg h0 (.in(display[3:0]),   .seg(HEX0));
hex7seg h1 (.in(display[7:4]),   .seg(HEX1));
hex7seg h2 (.in(display[11:8]),  .seg(HEX2));
hex7seg h3 (.in(display[15:12]), .seg(HEX3));
hex7seg h4 (.in(display[19:16]), .seg(HEX4));
hex7seg h5 (.in(display[23:20]), .seg(HEX5));

endmodule