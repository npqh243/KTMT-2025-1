// ==========================================
// MODULE CHÍNH: ALU_BIG_MODULE
// Giữ nguyên input/output ports như yêu cầu
// ==========================================
module ALU_BIG_MODULE (
    input  wire [1:0]  ForwardA,
    input  wire [1:0]  ForwardB,
    input  wire [31:0] read_data_1,
    input  wire [31:0] read_data_2,
    input  wire [31:0] EX_MEM_alu_result,
    input  wire [31:0] MEM_WB_read_data,   // *** LƯU Ý: NÊN NỐI FINAL WRITEBACK DATA Ở TOP ***
    input  wire [31:0] ins_15_0,           // Immediate đã sign-extend 32-bit
    input  wire [2:0]  alu_op,
    input  wire        alu_src,

    output wire [31:0] alu_result,
    output wire [31:0] write_data
);

    // --------------------------------------------------------
    // 1) Forwarding MUX cho input A của ALU
    // --------------------------------------------------------
    wire [31:0] alu_in_a;
    assign alu_in_a =
        (ForwardA == 2'b10) ? EX_MEM_alu_result :
        (ForwardA == 2'b01) ? MEM_WB_read_data  :
                              read_data_1;

    // --------------------------------------------------------
    // 2) Forwarding MUX cho input B gốc (dùng cho sw / hoặc alu_src=0)
    // --------------------------------------------------------
    wire [31:0] forward_b_out;
    assign forward_b_out =
        (ForwardB == 2'b10) ? EX_MEM_alu_result :
        (ForwardB == 2'b01) ? MEM_WB_read_data  :
                              read_data_2;

    // Dữ liệu store (sw) phải lấy sau forwarding
    assign write_data = forward_b_out;

    // --------------------------------------------------------
    // 3) MUX chọn ALU input B: regB hoặc immediate
    // alu_src = 0 -> dùng register (forward_b_out)
    // alu_src = 1 -> dùng immediate (ins_15_0)
    // --------------------------------------------------------
    wire [31:0] alu_in_b;
    assign alu_in_b = (alu_src) ? ins_15_0 : forward_b_out;

    // --------------------------------------------------------
    // 4) ALU CONTROL: tương thích CONTROL_UNIT
    // - alu_op = 010 => R-type dùng funct
    // - alu_op = 000 => ADD
    // - alu_op = 001 => SUB
    // - alu_op = 011 => I-type (không đủ info để phân biệt -> default ADD)
    // --------------------------------------------------------
    wire [2:0] alu_sel_internal;
    ALU_CONTROL u_alu_ctrl (
        .ALU_Op  (alu_op),
        .Funct   (ins_15_0[5:0]),   // ⚠️ chỉ đúng nếu ID/EX giữ đúng funct cho R-type
        .ALU_Sel (alu_sel_internal)
    );

    // --------------------------------------------------------
    // 5) ALU CORE
    // --------------------------------------------------------
    ALU u_alu (
        .ALU_In_0 (alu_in_a),
        .ALU_In_1 (alu_in_b),
        .ALU_Sel  (alu_sel_internal),
        .ALU_Out  (alu_result)
    );

endmodule


// ==========================================
// ALU_CONTROL: TƯƠNG THÍCH CONTROL_UNIT
// ==========================================
module ALU_CONTROL (
    input  wire [2:0] ALU_Op,
    input  wire [5:0] Funct,
    output reg  [2:0] ALU_Sel
);
    // Định nghĩa các mã lệnh nhận từ Control Unit
    localparam OP_ADD_LW_SW = 3'b000;
    localparam OP_SUB_BEQ   = 3'b001;
    localparam OP_R_TYPE    = 3'b010; 
    localparam OP_ANDI      = 3'b011;
    localparam OP_ORI       = 3'b100;
    localparam OP_XORI      = 3'b101;
    localparam OP_SLTI      = 3'b110;

    // Định nghĩa output điều khiển ALU Core (phải khớp module ALU)
    localparam SEL_ADD = 3'b000;
    localparam SEL_SUB = 3'b001;
    localparam SEL_AND = 3'b010;
    localparam SEL_OR  = 3'b011;
    localparam SEL_XOR = 3'b100;
    localparam SEL_SLT = 3'b101;

    always @(*) begin
        case (ALU_Op)
            // 1. Trường hợp lw, sw, addi -> Phép cộng
            OP_ADD_LW_SW: ALU_Sel = SEL_ADD;

            // 2. Trường hợp beq -> Phép trừ
            OP_SUB_BEQ:   ALU_Sel = SEL_SUB;

            // 3. Trường hợp Logic Immediate (andi, ori, xori)
            OP_ANDI:      ALU_Sel = SEL_AND;
            OP_ORI:       ALU_Sel = SEL_OR;
            OP_XORI:      ALU_Sel = SEL_XOR;
            OP_SLTI:      ALU_Sel = SEL_SLT; // SLT thường dùng phép trừ để so sánh

            // 4. Trường hợp R-Type -> Phụ thuộc vào Funct
            OP_R_TYPE: begin
                case (Funct)
                    6'h20: ALU_Sel = SEL_ADD; // add
                    6'h22: ALU_Sel = SEL_SUB; // sub
                    6'h24: ALU_Sel = SEL_AND; // and
                    6'h25: ALU_Sel = SEL_OR;  // or
                    6'h26: ALU_Sel = SEL_XOR; // xor
                    // MIPS chuẩn còn có slt (0x2A), nor (0x27)...
                    default: ALU_Sel = SEL_ADD; 
                endcase
            end

            default: ALU_Sel = SEL_ADD;
        endcase
    end
endmodule

// ==========================================
// ALU CORE
// ==========================================
module ALU (
    input  wire [31:0] ALU_In_0,
    input  wire [31:0] ALU_In_1,
    input  wire [2:0]  ALU_Sel,
    output reg  [31:0] ALU_Out
);

    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_XOR = 3'b100;
    localparam ALU_SLT = 3'b101;

    always @(*) begin
        case (ALU_Sel)
            ALU_ADD: ALU_Out = ALU_In_0 + ALU_In_1;
            ALU_SUB: ALU_Out = ALU_In_0 - ALU_In_1;
            ALU_AND: ALU_Out = ALU_In_0 & ALU_In_1;
            ALU_OR : ALU_Out = ALU_In_0 | ALU_In_1;
            ALU_XOR: ALU_Out = ALU_In_0 ^ ALU_In_1;
            ALU_SLT: ALU_Out = (ALU_In_0 < ALU_In_1) ? 32'd1 : 32'd0;
            default: ALU_Out = 32'd0;
        endcase
    end
endmodule
