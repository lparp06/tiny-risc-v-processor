module alu
(
	input		[31:0]	a,
	input		[31:0]	b,
	input		[3:0]		op,
	output	reg [31:0]	out

);

wire signed [31:0] s_a, s_b; 

assign s_a = a;
assign s_b = b;


parameter ADD = 4'd0,
			 SUB = 4'd1,
			 AND = 4'd2,
			 OR = 4'd3,
			 XOR = 4'd4,
			 SLT = 4'd5,
			 SLTU = 4'd6,
			 SLL = 4'd7,
			 SRL = 4'd8,
			 SRA = 4'd9,
			 MUL = 4'd10;

always @ (*)
begin
	case (op)
		ADD: out = a + b;
		SUB: out = a - b;
		AND: out = a & b;
		OR: out = a | b;
		XOR: out = a ^ b;
		SLT: out = {31'b0, s_a < s_b};
		SLTU: out = {31'b0, a < b};
		SLL: out = a << b[4:0];
		SRL: out = a >> b[4:0];
		SRA: out = s_a >>> b[4:0];
		MUL: out = s_a * s_b;
		default: out = 32'b0;
	endcase	
end

endmodule