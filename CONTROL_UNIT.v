module CONTROL_UNIT (
    input wire [5:0] opcode,
    output reg       pc_src, reg_dst, alu_src, mem_to_reg, 
                     reg_write, mem_read, mem_write, branch, jump,
    output reg [2:0] alu_op // 3-bit code
);
    // Định nghĩa các opcode
    localparam R_Type = 6'h00; 
    localparam j      = 6'h02;
    localparam beq    = 6'h04;
    localparam addi   = 6'h08;
    localparam slti   = 6'h0A;
    localparam andi   = 6'h0C;
    localparam ori    = 6'h0D;
    localparam xori   = 6'h0E;
    localparam lw     = 6'h23;
    localparam sw     = 6'h2B;
    
    always @(*) begin
        // Reset defaults...
        {reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump} = 0;
        alu_op = 3'b000; // Mặc định là ADD (cho lw, sw)

        case (opcode)
            // R-TYPE: Đặt mã riêng là 010
            R_Type: begin
                reg_dst = 1; reg_write = 1;
                alu_op = 3'b010; // <--- SỬA: Mã 010 để báo hiệu R-Type
            end

            // LW/SW/ADDI: Dùng mã 000 (Mặc định)
            lw: begin
                alu_src = 1; mem_to_reg = 1; reg_write = 1; mem_read = 1;
                alu_op = 3'b000; // ADD
            end
            sw: begin
                alu_src = 1; mem_write = 1;
                alu_op = 3'b000; // ADD
            end
            addi: begin
                alu_src = 1; reg_write = 1;
                alu_op = 3'b000; // ADD
            end

            // BRANCH: Dùng mã 001 (SUB)
            beq: begin
                branch = 1;
            end

            // LOGIC IMMEDIATE: Gán mã cụ thể
            andi: begin
                alu_src = 1; reg_write = 1;
                alu_op = 3'b011; // Mapping sang AND
            end
            ori: begin
                alu_src = 1; reg_write = 1;
                alu_op = 3'b100; // Mapping sang OR
            end
            xori: begin
                alu_src = 1; reg_write = 1;
                alu_op = 3'b101; 
            end
            slti: begin
                alu_src = 1; reg_write = 1;
                alu_op = 3'b110; // Mapping sang SLT
            end
            
            // JUMP
            j: begin jump = 1; end
            
            default: begin end
        endcase
    end
endmodule