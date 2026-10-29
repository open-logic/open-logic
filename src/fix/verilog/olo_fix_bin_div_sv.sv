`default_nettype none

module olo_fix_bin_div_sv
 #(
   parameter string NumFmt_g,
   parameter string DenomFmt_g,
   parameter string OutFmt_g,
   parameter string Mode_g = "PIPELINED",
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Sat_c)
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   output logic In_Ready,
   input wire [olo_fix_sv_pkg::fixFmtFromString(NumFmt_g)-1: 0] In_Num,
   input wire [olo_fix_sv_pkg::fixFmtFromString(DenomFmt_g)-1: 0] In_Denom,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Quot
  );

  // very shallow wrapper
olo_fix_bin_div
 #(
  .NumFmt_g (NumFmt_g),
  .DenomFmt_g (DenomFmt_g),
  .OutFmt_g (OutFmt_g),
  .Mode_g (Mode_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_Ready (In_Ready), // out
  .In_Num (In_Num), // in
  .In_Denom (In_Denom), // in
  .Out_Valid (Out_Valid), // out
  .Out_Quot (Out_Quot) // out
);

endmodule

`default_nettype wire

