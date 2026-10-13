`default_nettype none

module olo_fix_madd_sv
 #(
   parameter  PreAdd_g = 0,
   parameter  InBIsCoef_g = 0,
   parameter string PreAddOp_g = "Add",
   parameter string Operation_g = "Add",
   parameter string AFmt_g,
   parameter string BFmt_g,
   parameter string CFmt_g = "(0,0,0)",
   parameter string AddChainFmt_g,
   parameter  MultRegs_g = 1)
  (
   input wire Clk,
   input wire Rst,
   input wire InAC_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] InA_Data,
   input wire [olo_fix_sv_pkg::fixFmtFromString(CFmt_g)-1: 0] InC_Data,
   input wire InB_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(BFmt_g)-1: 0] InB_Data,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AddChainFmt_g)-1: 0] MaccIn,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(AddChainFmt_g)-1: 0] Out_Data
  );

  // very shallow wrapper
olo_fix_madd
 #(
  .PreAdd_g (PreAdd_g),
  .InBIsCoef_g (InBIsCoef_g),
  .PreAddOp_g (PreAddOp_g),
  .Operation_g (Operation_g),
  .AFmt_g (AFmt_g),
  .BFmt_g (BFmt_g),
  .CFmt_g (CFmt_g),
  .AddChainFmt_g (AddChainFmt_g),
  .MultRegs_g (MultRegs_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .InAC_Valid (InAC_Valid), // in
  .InA_Data (InA_Data), // in
  .InC_Data (InC_Data), // in
  .InB_Valid (InB_Valid), // in
  .InB_Data (InB_Data), // in
  .MaccIn (MaccIn), // in
  .Out_Valid (Out_Valid), // out
  .Out_Data (Out_Data) // out
);

endmodule

`default_nettype wire

