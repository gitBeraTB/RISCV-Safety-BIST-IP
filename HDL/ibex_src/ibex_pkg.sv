

package ibex_pkg;

    // ALU Operation Encoding 
    typedef enum logic [4:0] {
        ALU_ADD   = 5'b00000,
        ALU_SUB   = 5'b00001,
        ALU_AND   = 5'b00010,
        ALU_OR    = 5'b00011,
        ALU_XOR   = 5'b00100,
        ALU_SLT   = 5'b00101,
        ALU_SLTU  = 5'b00111,
        ALU_SLL   = 5'b00110,
        ALU_SRL   = 5'b01000,
        ALU_SRA   = 5'b01001
        
    } alu_op_e;

    // Multiplier/Divider Operations (Dummy definition to satisfy port list)
    typedef enum logic [2:0] {
        MD_OP_MULL = 3'b000
    } md_op_e;

endpackage