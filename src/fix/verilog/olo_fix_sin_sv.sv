`default_nettype none

module olo_fix_sin_sv
 #(
   parameter string OutFmt_g,
   parameter string InFmt_g,
   parameter  CosOutput_g = 0,
   parameter string MemStyle_g = "auto",
   parameter string Round_g = olo_fix_sv_pkg::FixRound_NonSymPos_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Sat_c)
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Sin,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Cos
  );

  // very shallow wrapper
olo_fix_sin
 #(
  .OutFmt_g (OutFmt_g),
  .InFmt_g (InFmt_g),
  .CosOutput_g (CosOutput_g),
  .MemStyle_g (MemStyle_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_Data (In_Data), // in
  .Out_Valid (Out_Valid), // out
  .Out_Sin (Out_Sin), // out
  .Out_Cos (Out_Cos) // out
);

endmodule

`default_nettype wire

