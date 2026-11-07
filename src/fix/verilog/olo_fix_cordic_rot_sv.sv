`default_nettype none

module olo_fix_cordic_rot_sv
 #(
   parameter string InMagFmt_g,
   parameter string InAngFmt_g,
   parameter string OutFmt_g,
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
   input wire [olo_fix_sv_pkg::fixFmtFromString(InMagFmt_g)-1: 0] In_Mag,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InAngFmt_g)-1: 0] In_Ang,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_I,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Q
  );

  // very shallow wrapper
olo_fix_cordic_rot
 #(
  .InMagFmt_g (InMagFmt_g),
  .InAngFmt_g (InAngFmt_g),
  .OutFmt_g (OutFmt_g),
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
  .In_Mag (In_Mag), // in
  .In_Ang (In_Ang), // in
  .Out_Valid (Out_Valid), // out
  .Out_I (Out_I), // out
  .Out_Q (Out_Q) // out
);

endmodule

`default_nettype wire

