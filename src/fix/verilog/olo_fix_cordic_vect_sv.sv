`default_nettype none

module olo_fix_cordic_vect_sv
 #(
   parameter string InFmt_g,
   parameter string OutMagFmt_g,
   parameter string OutAngFmt_g,
   parameter string IntXyFmt_g = "AUTO",
   parameter string IntAngFmt_g = "AUTO",
   parameter  Iterations_g,
   parameter string Mode_g = "PIPELINED",
   parameter string GainCorrCoefFmt_g = "(0,0,17)",
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c)
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   output logic In_Ready,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_I,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Q,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutMagFmt_g)-1: 0] Out_Mag,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutAngFmt_g)-1: 0] Out_Ang
  );

  // very shallow wrapper
olo_fix_cordic_vect
 #(
  .InFmt_g (InFmt_g),
  .OutMagFmt_g (OutMagFmt_g),
  .OutAngFmt_g (OutAngFmt_g),
  .IntXyFmt_g (IntXyFmt_g),
  .IntAngFmt_g (IntAngFmt_g),
  .Iterations_g (Iterations_g),
  .Mode_g (Mode_g),
  .GainCorrCoefFmt_g (GainCorrCoefFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_Ready (In_Ready), // out
  .In_I (In_I), // in
  .In_Q (In_Q), // in
  .Out_Valid (Out_Valid), // out
  .Out_Mag (Out_Mag), // out
  .Out_Ang (Out_Ang) // out
);

endmodule

`default_nettype wire

