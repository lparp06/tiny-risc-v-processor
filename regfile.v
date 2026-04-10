module regfile (
	input clk,
	input rst,
	input [4:0] ra0,
	input [4:0] ra1,
	output reg [31:0] rd0,
	output reg [31:0] rd1,
	input [4:0] waddr,
	input [31:0] wdata,
	input wen
);

reg [31:0] r0;
reg [31:0] r1;
reg [31:0] r2;
reg [31:0] r3;
reg [31:0] r4;
reg [31:0] r5;
reg [31:0] r6;
reg [31:0] r7;
reg [31:0] r8;
reg [31:0] r9;
reg [31:0] r10;
reg [31:0] r11;
reg [31:0] r12;
reg [31:0] r13;
reg [31:0] r14;
reg [31:0] r15;
reg [31:0] r16;
reg [31:0] r17;
reg [31:0] r18;
reg [31:0] r19;
reg [31:0] r20;
reg [31:0] r21;
reg [31:0] r22;
reg [31:0] r23;
reg [31:0] r24;
reg [31:0] r25;
reg [31:0] r26;
reg [31:0] r27;
reg [31:0] r28;
reg [31:0] r29;
reg [31:0] r30;
reg [31:0] r31;

always @(*) begin
	case (ra0)
		5'd0:  rd0 = 32'b0;
		5'd1:  rd0 = r1;
		5'd2:  rd0 = r2;
		5'd3:  rd0 = r3;
		5'd4:  rd0 = r4;
		5'd5:  rd0 = r5;
		5'd6:  rd0 = r6;
		5'd7:  rd0 = r7;
		5'd8:  rd0 = r8;
		5'd9:  rd0 = r9;
		5'd10: rd0 = r10;
		5'd11: rd0 = r11;
		5'd12: rd0 = r12;
		5'd13: rd0 = r13;
		5'd14: rd0 = r14;
		5'd15: rd0 = r15;
		5'd16: rd0 = r16;
		5'd17: rd0 = r17;
		5'd18: rd0 = r18;
		5'd19: rd0 = r19;
		5'd20: rd0 = r20;
		5'd21: rd0 = r21;
		5'd22: rd0 = r22;
		5'd23: rd0 = r23;
		5'd24: rd0 = r24;
		5'd25: rd0 = r25;
		5'd26: rd0 = r26;
		5'd27: rd0 = r27;
		5'd28: rd0 = r28;
		5'd29: rd0 = r29;
		5'd30: rd0 = r30;
		5'd31: rd0 = r31;
		default: rd0 = 32'b0;
	endcase
end

always @(*) begin
	case (ra1)
		5'd0:  rd1 = 32'b0;
		5'd1:  rd1 = r1;
		5'd2:  rd1 = r2;
		5'd3:  rd1 = r3;
		5'd4:  rd1 = r4;
		5'd5:  rd1 = r5;
		5'd6:  rd1 = r6;
		5'd7:  rd1 = r7;
		5'd8:  rd1 = r8;
		5'd9:  rd1 = r9;
		5'd10: rd1 = r10;
		5'd11: rd1 = r11;
		5'd12: rd1 = r12;
		5'd13: rd1 = r13;
		5'd14: rd1 = r14;
		5'd15: rd1 = r15;
		5'd16: rd1 = r16;
		5'd17: rd1 = r17;
		5'd18: rd1 = r18;
		5'd19: rd1 = r19;
		5'd20: rd1 = r20;
		5'd21: rd1 = r21;
		5'd22: rd1 = r22;
		5'd23: rd1 = r23;
		5'd24: rd1 = r24;
		5'd25: rd1 = r25;
		5'd26: rd1 = r26;
		5'd27: rd1 = r27;
		5'd28: rd1 = r28;
		5'd29: rd1 = r29;
		5'd30: rd1 = r30;
		5'd31: rd1 = r31;
		default: rd1 = 32'b0;
	endcase
end

always @(posedge clk or negedge rst) begin
	if (!rst) begin
		r0  <= 32'b0;
		r1  <= 32'b0;
		r2  <= 32'b0;
		r3  <= 32'b0;
		r4  <= 32'b0;
		r5  <= 32'b0;
		r6  <= 32'b0;
		r7  <= 32'b0;
		r8  <= 32'b0;
		r9  <= 32'b0;
		r10 <= 32'b0;
		r11 <= 32'b0;
		r12 <= 32'b0;
		r13 <= 32'b0;
		r14 <= 32'b0;
		r15 <= 32'b0;
		r16 <= 32'b0;
		r17 <= 32'b0;
		r18 <= 32'b0;
		r19 <= 32'b0;
		r20 <= 32'b0;
		r21 <= 32'b0;
		r22 <= 32'b0;
		r23 <= 32'b0;
		r24 <= 32'b0;
		r25 <= 32'b0;
		r26 <= 32'b0;
		r27 <= 32'b0;
		r28 <= 32'b0;
		r29 <= 32'b0;
		r30 <= 32'b0;
		r31 <= 32'b0;
	end
	else begin
		if (wen) begin
			case (waddr)
				5'd0:  r0  <= 32'b0;
				5'd1:  r1  <= wdata;
				5'd2:  r2  <= wdata;
				5'd3:  r3  <= wdata;
				5'd4:  r4  <= wdata;
				5'd5:  r5  <= wdata;
				5'd6:  r6  <= wdata;
				5'd7:  r7  <= wdata;
				5'd8:  r8  <= wdata;
				5'd9:  r9  <= wdata;
				5'd10: r10 <= wdata;
				5'd11: r11 <= wdata;
				5'd12: r12 <= wdata;
				5'd13: r13 <= wdata;
				5'd14: r14 <= wdata;
				5'd15: r15 <= wdata;
				5'd16: r16 <= wdata;
				5'd17: r17 <= wdata;
				5'd18: r18 <= wdata;
				5'd19: r19 <= wdata;
				5'd20: r20 <= wdata;
				5'd21: r21 <= wdata;
				5'd22: r22 <= wdata;
				5'd23: r23 <= wdata;
				5'd24: r24 <= wdata;
				5'd25: r25 <= wdata;
				5'd26: r26 <= wdata;
				5'd27: r27 <= wdata;
				5'd28: r28 <= wdata;
				5'd29: r29 <= wdata;
				5'd30: r30 <= wdata;
				5'd31: r31 <= wdata;
				default: r0 <= 32'b0;
			endcase
		end

		r0 <= 32'b0;
	end
end

endmodule