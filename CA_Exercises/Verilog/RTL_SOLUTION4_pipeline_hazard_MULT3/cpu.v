//Module: CPU
//Function: CPU is the top design of the RISC-V processor

//Inputs:
//	clk: main clock
//	arst_n: reset 
// enable: Starts the execution
//	addr_ext: Address for reading/writing content to Instruction Memory
//	wen_ext: Write enable for Instruction Memory
// ren_ext: Read enable for Instruction Memory
//	wdata_ext: Write word for Instruction Memory
//	addr_ext_2: Address for reading/writing content to Data Memory
//	wen_ext_2: Write enable for Data Memory
// ren_ext_2: Read enable for Data Memory
//	wdata_ext_2: Write word for Data Memory

// Outputs:
//	rdata_ext: Read data from Instruction Memory
//	rdata_ext_2: Read data from Data Memory



module cpu(
		input  wire			  clk,
		input  wire         arst_n,
		input  wire         enable,
		input  wire	[63:0]  addr_ext,
		input  wire         wen_ext,
		input  wire         ren_ext,
		input  wire [31:0]  wdata_ext,
		input  wire	[63:0]  addr_ext_2,
		input  wire         wen_ext_2,
		input  wire         ren_ext_2,
		input  wire [63:0]  wdata_ext_2,
		
		output wire	[31:0]  rdata_ext,
		output wire	[63:0]  rdata_ext_2

   );

reg               pc_src;
wire              zero_flag;
wire [      63:0] branch_pc,updated_pc,current_pc,jump_pc;
wire [      31:0] instruction;
wire [       1:0] alu_op;
wire [       3:0] alu_control;
wire              reg_dst,branch,mem_read,mem_2_reg,
                  mem_write,alu_src, reg_write, jump;
wire [       4:0] regfile_waddr;
wire [      63:0] regfile_wdata,mem_data,alu_out,
                  regfile_rdata_1,regfile_rdata_2,
                  alu_operand_2, alu_operand_A, alu_operand_B;
wire [       1:0] forward_select_a, forward_select_b;

wire signed [63:0] immediate_extended;


//////////////////////// PIPELINE wiring ////////////////////////

wire [      95:0] pipeline_IF_ID_in     = {instruction, updated_pc}; //(64+32+)
wire [      95:0] pipeline_IF_ID_out;
wire              pipeline_IF_ID_en     = 1'b1;

wire [      31:0] instruction_ID        = pipeline_IF_ID_out[  95:64];
wire [      63:0] updated_pc_ID         = pipeline_IF_ID_out[   63:0];

wire [     297:0] pipeline_ID_EX_in     = {regfile_rdata_1, regfile_rdata_2, immediate_extended, instruction_ID, updated_pc_ID, 
                                           alu_op, reg_dst, branch, mem_read, mem_2_reg, mem_write, alu_src, reg_write, jump}; //(64+64+64+32+64+2+8)
wire [     297:0] pipeline_ID_EX_out;
wire              pipeline_ID_EX_en     = 1'b1;

wire [      63:0] regfile_rdata_1_EX    = pipeline_ID_EX_out[297:234];
wire [      63:0] regfile_rdata_2_EX    = pipeline_ID_EX_out[233:170];
wire [      63:0] immediate_extended_EX = pipeline_ID_EX_out[169:106];
wire [      31:0] instruction_EX        = pipeline_ID_EX_out[ 105:74];
wire [      63:0] updated_pc_EX         = pipeline_ID_EX_out[  73:10];
wire [       1:0] alu_op_EX             = pipeline_ID_EX_out[    9:8];
wire              reg_dst_EX            = pipeline_ID_EX_out[      7];
wire              branch_EX             = pipeline_ID_EX_out[      6];
wire              mem_read_EX           = pipeline_ID_EX_out[      5];
wire              mem_2_reg_EX          = pipeline_ID_EX_out[      4];
wire              mem_write_EX          = pipeline_ID_EX_out[      3];
wire              alu_src_EX            = pipeline_ID_EX_out[      2];
wire              reg_write_EX          = pipeline_ID_EX_out[      1];
wire              jump_EX               = pipeline_ID_EX_out[      0];

wire [     295:0] pipeline_EX_MEM_in    = {regfile_rdata_2_EX, instruction_EX, branch_pc, jump_pc, alu_out, zero_flag,
                                           reg_dst_EX, branch_EX, mem_read_EX, mem_2_reg_EX, mem_write_EX, reg_write_EX, jump_EX}; //(64+32+64+64+64+8)
wire [     295:0] pipeline_EX_MEM_out;
wire              pipeline_EX_MEM_en    = 1'b1;

wire [      63:0] regfile_rdata_2_MEM   = pipeline_EX_MEM_out[295:232];
wire [      31:0] instruction_MEM       = pipeline_EX_MEM_out[231:200];
wire [      63:0] branch_pc_MEM         = pipeline_EX_MEM_out[199:136];
wire [      63:0] jump_pc_MEM           = pipeline_EX_MEM_out[ 135:72];
wire [      63:0] alu_out_MEM           = pipeline_EX_MEM_out[   71:8];
wire              zero_flag_MEM         = pipeline_EX_MEM_out[      7];
wire              reg_dst_MEM           = pipeline_EX_MEM_out[      6];
wire              branch_MEM            = pipeline_EX_MEM_out[      5];
wire              mem_read_MEM          = pipeline_EX_MEM_out[      4];
wire              mem_2_reg_MEM         = pipeline_EX_MEM_out[      3];
wire              mem_write_MEM         = pipeline_EX_MEM_out[      2];
wire              reg_write_MEM         = pipeline_EX_MEM_out[      1];
wire              jump_MEM              = pipeline_EX_MEM_out[      0];

wire [     162:0] pipeline_MEM_WB_in    = {mem_data, instruction_MEM, alu_out_MEM, reg_dst_MEM, mem_2_reg_MEM, reg_write_MEM}; //(64+32+64+3)
wire [     162:0] pipeline_MEM_WB_out;
wire              pipeline_MEM_WB_en    = 1'b1;

wire [      63:0] mem_data_WB           = pipeline_MEM_WB_out[ 162:99];
wire [      31:0] instruction_WB        = pipeline_MEM_WB_out[  98:67];
wire [      63:0] alu_out_WB            = pipeline_MEM_WB_out[   66:3];
wire              reg_dst_WB            = pipeline_MEM_WB_out[      2];
wire              mem_2_reg_WB          = pipeline_MEM_WB_out[      1];
wire              reg_write_WB          = pipeline_MEM_WB_out[      0];


////////////////////////// IF STAGE //////////////////////////

pc #(
   .DATA_W(64)
) program_counter (
   .clk       (clk          ),
   .arst_n    (arst_n       ),
   .branch_pc (branch_pc_MEM),
   .jump_pc   (jump_pc_MEM  ),
   .pc_src    (pc_src       ),
   //.zero_flag (zero_flag ),
   //.branch    (branch    ),
   .jump      (jump_MEM     ),
   .current_pc(current_pc   ),
   .enable    (enable       ),
   .updated_pc(updated_pc   )
);

sram_BW32 #(
   .ADDR_W(9 )
) instruction_memory(
   .clk      (clk           ),
   .addr     (current_pc    ),
   .wen      (1'b0          ),
   .ren      (1'b1          ),
   .wdata    (32'b0         ),
   .rdata    (instruction   ),   
   .addr_ext (addr_ext      ),
   .wen_ext  (wen_ext       ), 
   .ren_ext  (ren_ext       ),
   .wdata_ext(wdata_ext     ),
   .rdata_ext(rdata_ext     )
);

//////////////////////// END IF STAGE ////////////////////////

reg_arstn_en #(
   .DATA_W    (96),
   .PRESET_VAL(0 )
) REG_IF_ID (
      .clk   (clk               ),
      .arst_n(arst_n            ),
      .en    (pipeline_IF_ID_en ),
      .din   (pipeline_IF_ID_in ),
      .dout  (pipeline_IF_ID_out)

);

////////////////////////// ID STAGE //////////////////////////

immediate_extend_unit immediate_extend_u(
    .instruction         (instruction_ID    ),
    .immediate_extended  (immediate_extended)
);

control_unit control_unit(
   .opcode   (instruction_ID[6:0]),
   .alu_op   (alu_op             ),
   .reg_dst  (reg_dst            ),
   .branch   (branch             ),
   .mem_read (mem_read           ),
   .mem_2_reg(mem_2_reg          ),
   .mem_write(mem_write          ),
   .alu_src  (alu_src            ),
   .reg_write(reg_write          ),
   .jump     (jump               )
);

register_file #(
   .DATA_W(64)
) register_file(
   .clk      (clk                     ),
   .arst_n   (arst_n                  ),
   .reg_write(reg_write_WB            ),
   .raddr_1  (instruction_ID[19:15]   ),
   .raddr_2  (instruction_ID[24:20]   ),
   .waddr    (instruction_WB[11:7]    ),
   .wdata    (regfile_wdata           ),
   .rdata_1  (regfile_rdata_1         ),
   .rdata_2  (regfile_rdata_2         )
);

//////////////////////// END ID STAGE ////////////////////////

reg_arstn_en #(
   .DATA_W    (298),
   .PRESET_VAL(0  )
) REG_ID_EX (
      .clk   (clk               ),
      .arst_n(arst_n            ),
      .en    (pipeline_ID_EX_en ),
      .din   (pipeline_ID_EX_in ),
      .dout  (pipeline_ID_EX_out)

);

////////////////////////// EX STAGE //////////////////////////

alu_control alu_ctrl(
   .func7_5_0      ({instruction_EX[30], instruction_EX[25]}),
   .func3          (instruction_EX[14:12]),
   .alu_op         (alu_op_EX            ),
   .alu_control    (alu_control          )
);

mux_2 #(
   .DATA_W(64)
) alu_operand_mux (
   .input_a (immediate_extended_EX),
   .input_b (regfile_rdata_2_EX   ),
   .select_a(alu_src_EX           ),
   .mux_out (alu_operand_2        )
);

forwarding_unit forwarding_unit(
   .reg_write_MEM(reg_write_MEM        ),
   .reg_write_WB (reg_write_WB         ),
   .mem_2_reg_MEM(mem_2_reg_MEM        ),
   .mem_2_reg_WB (mem_2_reg_WB         ),
   .rs1_ID_EX    (instruction_EX[19:15]),
   .rs2_ID_EX    (instruction_EX[24:20]),
   .rd_EX_MEM    (instruction_MEM[11:7]),
   .rd_MEM_WB    (instruction_WB[ 11:7]),
   .mux_select_a (forward_select_a     ),
   .mux_select_b (forward_select_b     )
);

mux_3 #(
   .DATA_W(64)
) forwarding_mux_a (
   .input_a (regfile_rdata_1_EX),
   .input_b (regfile_wdata),
   .input_c (alu_out_MEM),
   .select_a(forward_select_a),
   .mux_out (alu_operand_A)
);

mux_3 #(
   .DATA_W(64)
) forwarding_mux_b (
   .input_a (alu_operand_2),
   .input_b (regfile_wdata),
   .input_c (alu_out_MEM),
   .select_a(forward_select_b),
   .mux_out (alu_operand_B)
);

alu#(
   .DATA_W(64)
) alu(
   .alu_in_0 (alu_operand_A      ),
   .alu_in_1 (alu_operand_B      ),
   .alu_ctrl (alu_control        ),
   .alu_out  (alu_out            ),
   .zero_flag(zero_flag          ),
   .overflow (                   )
);

branch_unit#(
   .DATA_W(64)
)branch_unit(
   .updated_pc         (updated_pc_EX        ),
   .immediate_extended (immediate_extended_EX),
   .branch_pc          (branch_pc            ),
   .jump_pc            (jump_pc              )
);

//////////////////////// END EX STAGE ////////////////////////

reg_arstn_en #(
   .DATA_W    (296),
   .PRESET_VAL(0  )
) REG_EX_MEM (
      .clk   (clk                ),
      .arst_n(arst_n             ),
      .en    (pipeline_EX_MEM_en ),
      .din   (pipeline_EX_MEM_in ),
      .dout  (pipeline_EX_MEM_out)

);

////////////////////////// MEM STAGE /////////////////////////

sram_BW64 #(
   .ADDR_W(10)
) data_memory(
   .clk      (clk                ),
   .addr     (alu_out_MEM        ),
   .wen      (mem_write_MEM      ),
   .ren      (mem_read_MEM       ),
   .wdata    (regfile_rdata_2_MEM),
   .rdata    (mem_data           ),   
   .addr_ext (addr_ext_2         ),
   .wen_ext  (wen_ext_2          ),
   .ren_ext  (ren_ext_2          ),
   .wdata_ext(wdata_ext_2        ),
   .rdata_ext(rdata_ext_2        )
);

always@(*) pc_src = zero_flag_MEM & branch_MEM;

//////////////////////// END MEM STAGE ///////////////////////

reg_arstn_en #(
   .DATA_W    (163),
   .PRESET_VAL(0  )
) REG_MEM_WB (
      .clk   (clk),
      .arst_n(arst_n),
      .en    (pipeline_MEM_WB_en),
      .din   (pipeline_MEM_WB_in),
      .dout  (pipeline_MEM_WB_out)

);

////////////////////////// WB STAGE //////////////////////////

mux_2 #(
   .DATA_W(64)
) regfile_data_mux (
   .input_a  (mem_data_WB     ),
   .input_b  (alu_out_WB      ),
   .select_a (mem_2_reg_WB    ),
   .mux_out  (regfile_wdata   )
);

//////////////////////// END WB STAGE ////////////////////////

endmodule


