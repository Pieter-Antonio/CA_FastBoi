
// 1a. EX/MEM.RegisterRd =ID/EX.RegisterRs1
// 1b. EX/MEM.RegisterRd =ID/EX.RegisterRs2
// 2a. MEM/WB.RegisterRd =ID/EX.RegisterRs1
// 2b. MEM/WB.RegisterRd =ID/EX.RegisterRs2
module forwarding_unit (
    input wire       reg_write_MEM,
    input wire       reg_write_WB,
    input wire       mem_2_reg_MEM,
    input wire       mem_2_reg_WB,
    input wire [4:0] rs1_ID_EX,
    input wire [4:0] rs2_ID_EX,
    input wire [4:0] rd_EX_MEM,
    input wire [4:0] rd_MEM_WB,
    output reg [1:0] mux_select_a,
    output reg [1:0] mux_select_b
);

wire comparator_hazard_1a = (rs1_ID_EX == rd_EX_MEM & reg_write_MEM & ~mem_2_reg_MEM);
wire comparator_hazard_1b = (rs2_ID_EX == rd_EX_MEM & reg_write_MEM & ~mem_2_reg_MEM);
wire comparator_hazard_2a = (rs1_ID_EX == rd_MEM_WB & reg_write_WB  & ~mem_2_reg_WB );
wire comparator_hazard_2b = (rs2_ID_EX == rd_MEM_WB & reg_write_WB  & ~mem_2_reg_WB );

assign mux_select_a = {comparator_hazard_1a, comparator_hazard_2a};
assign mux_select_b = {comparator_hazard_1b, comparator_hazard_2b};

endmodule