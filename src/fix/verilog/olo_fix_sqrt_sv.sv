`default_nettype none

module olo_fix_sqrt_sv
 #(
   parameter string OutFmt_g,
   parameter string InFmt_g,
   parameter  PrecisionBits_g = 18,
   parameter string MemStyle_g = "auto",
   parameter string Round_g = olo_fix_sv_pkg::FixRound_NonSymPos_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Sat_c)
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Result
  );

  // very shallow wrapper
olo_fix_sqrt
 #(
  .OutFmt_g (OutFmt_g),
  .InFmt_g (InFmt_g),
  .PrecisionBits_g (PrecisionBits_g),
  .MemStyle_g (MemStyle_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_Data (In_Data), // in
  .Out_Valid (Out_Valid), // out
  .Out_Result (Out_Result) // out
);

endmodule

`default_nettype wire

