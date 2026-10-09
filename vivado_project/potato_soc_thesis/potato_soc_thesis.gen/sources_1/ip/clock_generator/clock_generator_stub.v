// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Fri Oct  9 03:23:55 2026
// Host        : AndrasPC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/RISC-V-Soft-Core-AXI-Hardware-Accelerator-Thesis/vivado_project/potato_soc_thesis/potato_soc_thesis.gen/sources_1/ip/clock_generator/clock_generator_stub.v
// Design      : clock_generator
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clock_generator(system_clk, resetn, locked, clk_in1)
/* synthesis syn_black_box black_box_pad_pin="resetn,locked,clk_in1" */
/* synthesis syn_force_seq_prim="system_clk" */;
  output system_clk /* synthesis syn_isclock = 1 */;
  input resetn;
  output locked;
  input clk_in1;
endmodule
