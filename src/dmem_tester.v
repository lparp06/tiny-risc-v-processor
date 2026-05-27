module dmem_tester #(
    parameter ADDR_BITS = 10,
    parameter DEPTH     = 1024
)(
    input              clk,
    input              rst,      // active-low reset
    input              start,

    output reg [31:0]  addr,     // byte address to read/write
    output reg [31:0]  wdata,    // data to write
    output reg         wen,      // write enable
    input      [31:0]  rdata,    // data read back from memory

    output reg         done,         // test finished
    output reg         error,        // test failed
    output reg [ADDR_BITS-1:0] index,
    output reg [ADDR_BITS-1:0] error_index,
    output reg [31:0]  expected,
    output reg [31:0]  observed
);

// ------------------------------------------------------------
// FSM states
// ------------------------------------------------------------
//
// Test sequence:
//
//   1. WRITE_A:
//        Write pattern A to every memory word.
//
//   2. READ_A_SET / READ_A_WAIT / READ_A_CHECK:
//        Read each word back and verify pattern A.
//
//   3. WRITE_B:
//        Overwrite that same word with pattern B.
//
//   4. READ_B_SET / READ_B_WAIT / READ_B_CHECK:
//        Read the same word back and verify pattern B.
//
// This is intentionally conservative. The extra WAIT states give
// synchronous RAM time to update rdata after addr changes.

localparam IDLE         = 4'd0;

localparam WRITE_A      = 4'd1;

localparam READ_A_SET   = 4'd2;
localparam READ_A_WAIT  = 4'd3;
localparam READ_A_CHECK = 4'd4;

localparam WRITE_B      = 4'd5;

localparam READ_B_SET   = 4'd6;
localparam READ_B_WAIT  = 4'd7;
localparam READ_B_CHECK = 4'd8;

localparam DONE         = 4'd9;

reg [3:0] S;
reg [3:0] NS;

// ------------------------------------------------------------
// Test patterns
// ------------------------------------------------------------
//
// Each memory word gets a unique value based on its index.
// Pattern B is the bitwise inverse of pattern A.

function [31:0] pattern_a;
    input [ADDR_BITS-1:0] i;
    begin
        pattern_a = {{(32-ADDR_BITS){1'b0}}, i} ^ 32'hA5A55A5A;
    end
endfunction

function [31:0] pattern_b;
    input [ADDR_BITS-1:0] i;
    begin
        pattern_b = ~pattern_a(i);
    end
endfunction

// ------------------------------------------------------------
// State register
// ------------------------------------------------------------

always @(posedge clk or negedge rst) begin
    if (!rst)
        S <= IDLE;
    else
        S <= NS;
end

// ------------------------------------------------------------
// Next-state logic
// ------------------------------------------------------------

always @(*) begin
    NS = S;

    case (S)
        IDLE: begin
            if (start)
                NS = WRITE_A;
        end

        // Write pattern A to all memory words.
        WRITE_A: begin
            if (index == DEPTH-1)
                NS = READ_A_SET;
            else
                NS = WRITE_A;
        end

        // Set address for reading pattern A.
        READ_A_SET: begin
            NS = READ_A_WAIT;
        end

        // Wait one extra cycle for rdata to settle.
        READ_A_WAIT: begin
            NS = READ_A_CHECK;
        end

        // Check pattern A, then write pattern B at same index.
        READ_A_CHECK: begin
            if (rdata != pattern_a(index))
                NS = DONE;
            else
                NS = WRITE_B;
        end

        // Write pattern B at current index.
        WRITE_B: begin
            NS = READ_B_SET;
        end

        // Set address for reading pattern B.
        READ_B_SET: begin
            NS = READ_B_WAIT;
        end

        // Wait one extra cycle for rdata to settle.
        READ_B_WAIT: begin
            NS = READ_B_CHECK;
        end

        // Check pattern B. If this is the last word, finish.
        // Otherwise move to next index and check pattern A there.
        READ_B_CHECK: begin
            if (rdata != pattern_b(index))
                NS = DONE;
            else if (index == DEPTH-1)
                NS = DONE;
            else
                NS = READ_A_SET;
        end

        // Stay done until SW[7] / start is turned off.
        DONE: begin
            if (!start)
                NS = IDLE;
        end

        default: begin
            NS = IDLE;
        end
    endcase
end

// ------------------------------------------------------------
// Sequential datapath/control
// ------------------------------------------------------------

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        index       <= {ADDR_BITS{1'b0}};
        done        <= 1'b0;
        error       <= 1'b0;
        error_index <= {ADDR_BITS{1'b0}};
        expected    <= 32'd0;
        observed    <= 32'd0;
    end
    else begin
        case (S)
            IDLE: begin
                index       <= {ADDR_BITS{1'b0}};
                done        <= 1'b0;
                error       <= 1'b0;
                error_index <= {ADDR_BITS{1'b0}};
                expected    <= 32'd0;
                observed    <= 32'd0;
            end

            WRITE_A: begin
                if (index == DEPTH-1)
                    index <= {ADDR_BITS{1'b0}};
                else
                    index <= index + 1'b1;
            end

            READ_A_CHECK: begin
                if (rdata != pattern_a(index)) begin
                    done        <= 1'b1;
                    error       <= 1'b1;
                    error_index <= index;
                    expected    <= pattern_a(index);
                    observed    <= rdata;
                end
            end

            READ_B_CHECK: begin
                if (rdata != pattern_b(index)) begin
                    done        <= 1'b1;
                    error       <= 1'b1;
                    error_index <= index;
                    expected    <= pattern_b(index);
                    observed    <= rdata;
                end
                else if (index == DEPTH-1) begin
                    done        <= 1'b1;
                    error       <= 1'b0;
                    error_index <= index;
                    expected    <= pattern_b(index);
                    observed    <= rdata;
                end
                else begin
                    index <= index + 1'b1;
                end
            end

            DONE: begin
                if (!start) begin
                    index       <= {ADDR_BITS{1'b0}};
                    done        <= 1'b0;
                    error       <= 1'b0;
                    error_index <= {ADDR_BITS{1'b0}};
                    expected    <= 32'd0;
                    observed    <= 32'd0;
                end
            end
        endcase
    end
end

// ------------------------------------------------------------
// Output logic
// ------------------------------------------------------------
//
// addr is always the byte address for the current index.
// Since index is a word index, byte address = index * 4.
//
// For ADDR_BITS = 10:
//   20 + 10 + 2 = 32 bits

always @(*) begin
    addr  = {{(32-ADDR_BITS-2){1'b0}}, index, 2'b00};
    wdata = 32'd0;
    wen   = 1'b0;

    case (S)
        WRITE_A: begin
            wdata = pattern_a(index);
            wen   = 1'b1;
        end

        WRITE_B: begin
            wdata = pattern_b(index);
            wen   = 1'b1;
        end

        default: begin
            wdata = 32'd0;
            wen   = 1'b0;
        end
    endcase
end

endmodule