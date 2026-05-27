module control (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,

    output reg       reg_wen,
    output reg       alu_src_imm,
    output reg       alu_src_pc,
    output reg [3:0] alu_op,

    output reg       mem_wen,
    output reg [1:0] wb_sel,
    output reg [2:0] imm_sel,

    output reg       branch,
    output reg [2:0] branch_type,

    output reg       jump,
    output reg       jump_reg
);

parameter ALU_ADD  = 4'd0;
parameter ALU_SUB  = 4'd1;
parameter ALU_AND  = 4'd2;
parameter ALU_OR   = 4'd3;
parameter ALU_XOR  = 4'd4;
parameter ALU_SLT  = 4'd5;
parameter ALU_SLTU = 4'd6;
parameter ALU_SLL  = 4'd7;
parameter ALU_SRL  = 4'd8;
parameter ALU_SRA  = 4'd9;
parameter ALU_MUL  = 4'd10;

parameter WB_ALU = 2'd0;
parameter WB_MEM = 2'd1;
parameter WB_PC4 = 2'd2;
parameter WB_IMM = 2'd3;

parameter IMM_I = 3'd0;
parameter IMM_S = 3'd1;
parameter IMM_B = 3'd2;
parameter IMM_U = 3'd3;
parameter IMM_J = 3'd4;

parameter BR_BEQ  = 3'd0;
parameter BR_BNE  = 3'd1;
parameter BR_BLT  = 3'd2;
parameter BR_BGE  = 3'd3;
parameter BR_BLTU = 3'd4;
parameter BR_BGEU = 3'd5;

always @(*) begin
    // Safe default: NOP
    reg_wen     = 1'b0;
    alu_src_imm = 1'b0;
    alu_src_pc  = 1'b0;
    alu_op      = ALU_ADD;

    mem_wen     = 1'b0;
    wb_sel      = WB_ALU;
    imm_sel     = IMM_I;

    branch      = 1'b0;
    branch_type = BR_BEQ;

    jump        = 1'b0;
    jump_reg    = 1'b0;

    case (opcode)

        7'b0010011: begin // I-type ALU
            reg_wen     = 1'b1;
            alu_src_imm = 1'b1;
            wb_sel      = WB_ALU;
            imm_sel     = IMM_I;

            case (funct3)
                3'b000: alu_op = ALU_ADD;  // ADDI
                3'b111: alu_op = ALU_AND;  // ANDI
                3'b110: alu_op = ALU_OR;   // ORI
                3'b100: alu_op = ALU_XOR;  // XORI
                3'b010: alu_op = ALU_SLT;  // SLTI
                3'b011: alu_op = ALU_SLTU; // SLTIU
                3'b001: alu_op = ALU_SLL;  // SLLI

                3'b101: begin
						if (funct7 == 7'b0000000)
							alu_op = ALU_SRL;  // SRLI
						else if (funct7 == 7'b0100000)
							alu_op = ALU_SRA;  // SRAI
						else
							reg_wen = 1'b0;
					end

                default: reg_wen = 1'b0;
            endcase
        end

        7'b0110011: begin // R-type ALU
            reg_wen     = 1'b1;
            alu_src_imm = 1'b0;
            wb_sel      = WB_ALU;

            case ({funct7, funct3})
                {7'b0000000, 3'b000}: alu_op = ALU_ADD;  // ADD
                {7'b0100000, 3'b000}: alu_op = ALU_SUB;  // SUB
                {7'b0000000, 3'b111}: alu_op = ALU_AND;  // AND
                {7'b0000000, 3'b110}: alu_op = ALU_OR;   // OR
                {7'b0000000, 3'b100}: alu_op = ALU_XOR;  // XOR
                {7'b0000000, 3'b010}: alu_op = ALU_SLT;  // SLT
                {7'b0000000, 3'b011}: alu_op = ALU_SLTU; // SLTU
                {7'b0000000, 3'b001}: alu_op = ALU_SLL;  // SLL
                {7'b0000000, 3'b101}: alu_op = ALU_SRL;  // SRL
                {7'b0100000, 3'b101}: alu_op = ALU_SRA;  // SRA
                {7'b0000001, 3'b000}: alu_op = ALU_MUL;  // MUL
                default: reg_wen = 1'b0;
            endcase
        end

        7'b0000011: begin // LW
            if (funct3 == 3'b010) begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
                mem_wen     = 1'b0;
                wb_sel      = WB_MEM;
                imm_sel     = IMM_I;
            end
        end

        7'b0100011: begin // SW
            if (funct3 == 3'b010) begin
                reg_wen     = 1'b0;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
                mem_wen     = 1'b1;
                wb_sel      = WB_ALU;
                imm_sel     = IMM_S;
            end
        end

        7'b1100011: begin // Branches
            reg_wen     = 1'b0;
            alu_src_imm = 1'b0;
            mem_wen     = 1'b0;
            branch      = 1'b1;
            imm_sel     = IMM_B;

            case (funct3)
                3'b000: branch_type = BR_BEQ;
                3'b001: branch_type = BR_BNE;
                3'b100: branch_type = BR_BLT;
                3'b101: branch_type = BR_BGE;
                3'b110: branch_type = BR_BLTU;
                3'b111: branch_type = BR_BGEU;
                default: branch = 1'b0;
            endcase
        end

        7'b0110111: begin // LUI
            reg_wen = 1'b1;
            wb_sel  = WB_IMM;
            imm_sel = IMM_U;
        end

        7'b0010111: begin // AUIPC
            reg_wen     = 1'b1;
            alu_src_pc  = 1'b1;
            alu_src_imm = 1'b1;
            alu_op      = ALU_ADD;
            wb_sel      = WB_ALU;
            imm_sel     = IMM_U;
        end

        7'b1101111: begin // JAL
            reg_wen  = 1'b1;
            wb_sel   = WB_PC4;
            imm_sel  = IMM_J;
            jump     = 1'b1;
            jump_reg = 1'b0;
        end

        7'b1100111: begin // JALR
            if (funct3 == 3'b000) begin
                reg_wen     = 1'b1;
                alu_src_imm = 1'b1;
                alu_op      = ALU_ADD;
                wb_sel      = WB_PC4;
                imm_sel     = IMM_I;
                jump        = 1'b1;
                jump_reg    = 1'b1;
            end
        end

        default: begin
            // Defaults already make this a NOP.
        end

    endcase
end

endmodule