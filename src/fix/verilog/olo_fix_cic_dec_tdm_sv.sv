`default_nettype none

module olo_fix_cic_dec_tdm_sv
 #(
   parameter  Channels_g = 1,
   parameter  Order_g,
   parameter  Ratio_g,
   parameter  FixedRatio_g = 1,
   parameter  DiffDelay_g = 1,
   parameter string InFmt_g,
   parameter string OutFmt_g,
   parameter string GainCorrCoefFmt_g = "(0,1,16)",
   parameter string Round_g = olo_fix_sv_pkg::FixRound_NonSymPos_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter string RamBehavior_g = "RBW",
   parameter string RamStyle_g = "auto",
   parameter string Resource_g = "AUTO")
  (
   input wire Clk,
   input wire Rst,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Ratio_g)-1: 0] Cfg_Ratio,
   input wire [7: 0] Cfg_Shift,
   input wire [olo_fix_sv_pkg::fixFmtFromString(GainCorrCoefFmt_g)-1: 0] Cfg_GainCorr,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   input wire In_Last = '0,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Data,
   output logic Out_Last
  );

  // very shallow wrapper
olo_fix_cic_dec_tdm
 #(
  .Channels_g (Channels_g),
  .Order_g (Order_g),
  .Ratio_g (Ratio_g),
  .FixedRatio_g (FixedRatio_g),
  .DiffDelay_g (DiffDelay_g),
  .InFmt_g (InFmt_g),
  .OutFmt_g (OutFmt_g),
  .GainCorrCoefFmt_g (GainCorrCoefFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .RamBehavior_g (RamBehavior_g),
  .RamStyle_g (RamStyle_g),
  .Resource_g (Resource_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .Cfg_Ratio (Cfg_Ratio), // in
  .Cfg_Shift (Cfg_Shift), // in
  .Cfg_GainCorr (Cfg_GainCorr), // in
  .In_Valid (In_Valid), // in
  .In_Data (In_Data), // in
  .In_Last (In_Last), // in
  .Out_Valid (Out_Valid), // out
  .Out_Data (Out_Data), // out
  .Out_Last (Out_Last) // out
);

endmodule

`default_nettype wire

