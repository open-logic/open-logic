`default_nettype none

module olo_fix_mov_avg_sv
 #(
   parameter string InFmt_g,
   parameter string OutFmt_g,
   parameter  Taps_g,
   parameter string GainCorrCoefFmt_g = "(0,1,16)",
   parameter string GainCorrDataFmt_g = "AUTO",
   parameter string GainCorrType_g = "EXACT",
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter string RoundReg_g = "YES",
   parameter string SatReg_g = "YES",
   parameter string RamBehavior_g = "RBW",
   parameter string RamStyle_g = "auto",
   parameter string Resource_g = "AUTO")
  (
   input wire Clk = '0,
   input wire Rst = '0,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Result
  );

  // very shallow wrapper
olo_fix_mov_avg
 #(
  .InFmt_g (InFmt_g),
  .OutFmt_g (OutFmt_g),
  .Taps_g (Taps_g),
  .GainCorrCoefFmt_g (GainCorrCoefFmt_g),
  .GainCorrDataFmt_g (GainCorrDataFmt_g),
  .GainCorrType_g (GainCorrType_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .RoundReg_g (RoundReg_g),
  .SatReg_g (SatReg_g),
  .RamBehavior_g (RamBehavior_g),
  .RamStyle_g (RamStyle_g),
  .Resource_g (Resource_g))
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

