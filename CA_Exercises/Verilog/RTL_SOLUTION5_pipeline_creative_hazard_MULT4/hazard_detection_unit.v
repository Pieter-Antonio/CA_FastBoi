//Hazard Detection Unit
//Function: Flush the pipeline when a control hazard occurs
//Inputs:
//register_rs1_id: Current registerfile read address 1.
//register_rs2_id: Current registerfile read address 2.
//register_rd_ex: Target register address.
//mem_read_ex: Check wether data is read from the memory.
//Outputs: 
//flush_pipeline: Control signal to mux to flush the pipeline.
//pc_enable: Control wether the program counter updates.
//if_id_enable: Control wether the IF/ID register updates.

module hazard_detection_unit(
      input  wire [4:0] register_rs1_id,
      input  wire [4:0] register_rs2_id,
      input  wire [4:0] register_rd_ex,
      input  wire       mem_read_ex,
      output reg        flush_pipeline,
      output reg        pc_enable,
      output reg        if_id_enable
   );

    always @(*) begin // INSTRUCTION 17 IS EXECUTED TWICE INSTEAD OF INSTRUCTION 16
        if (mem_read_ex && ((register_rd_ex == register_rs1_id) || (register_rd_ex == register_rs2_id))) begin
            flush_pipeline <= 1'b1;
            pc_enable <= 1'b0;
            if_id_enable <= 1'b0;
        end else begin
            flush_pipeline <= 1'b0;
            pc_enable <= 1'b1;
            if_id_enable <= 1'b1;
        end
    end
  
endmodule

