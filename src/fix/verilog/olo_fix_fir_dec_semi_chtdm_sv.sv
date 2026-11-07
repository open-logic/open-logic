`default_nettype none

module olo_fix_fir_dec_semi_chtdm_sv
 #(
   parameter string InFmt_g,
   parameter string OutFmt_g,
   parameter string CoefFmt_g,
   parameter  Channels_g = 1,
   parameter  Ratio_g = 1,
   parameter  Taps_g,
   parameter  Multipliers_g,
   parameter  FullInpRateSupport_g = 0,
   parameter  GuardBits_g = 1,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter  MultRegs_g = 1,
   parameter string CoefInit_g = "0.0",
   parameter string CoefStorageType_g = "ROM",
   parameter  CoefRamReadback_g = 0,
   parameter string CoefRamBehavior_g = "RBW",
   parameter string CoefMemStyle_g = "auto",
   parameter string DataRamBehavior_g = "RBW",
   parameter string DataMemStyle_g = "auto")
  (
   input wire Clk,
   input wire Rst,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Taps_g)-1: 0] Coef_Addr,
   input wire Coef_WrEna = '0,
   input wire [olo_fix_sv_pkg::fixFmtFromString(CoefFmt_g)-1: 0] Coef_WrData,
   input wire Coef_RdEna = '0,
   output logic [olo_fix_sv_pkg::fixFmtFromString(CoefFmt_g)-1: 0] Coef_RdData,
   output logic Coef_RdValid,
   input wire Flush_Ena = '0,
   output logic Flush_Done,
   input wire In_Valid,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   input wire In_Last = '0,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Data,
   output logic Out_Last
  );

  // very shallow wrapper
olo_fix_fir_dec_semi_chtdm
 #(
  .InFmt_g (InFmt_g),
  .OutFmt_g (OutFmt_g),
  .CoefFmt_g (CoefFmt_g),
  .Channels_g (Channels_g),
  .Ratio_g (Ratio_g),
  .Taps_g (Taps_g),
  .Multipliers_g (Multipliers_g),
  .FullInpRateSupport_g (FullInpRateSupport_g),
  .GuardBits_g (GuardBits_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .MultRegs_g (MultRegs_g),
  .CoefInit_g (CoefInit_g),
  .CoefStorageType_g (CoefStorageType_g),
  .CoefRamReadback_g (CoefRamReadback_g),
  .CoefRamBehavior_g (CoefRamBehavior_g),
  .CoefMemStyle_g (CoefMemStyle_g),
  .DataRamBehavior_g (DataRamBehavior_g),
  .DataMemStyle_g (DataMemStyle_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .Coef_Addr (Coef_Addr), // in
  .Coef_WrEna (Coef_WrEna), // in
  .Coef_WrData (Coef_WrData), // in
  .Coef_RdEna (Coef_RdEna), // in
  .Coef_RdData (Coef_RdData), // out
  .Coef_RdValid (Coef_RdValid), // out
  .Flush_Ena (Flush_Ena), // in
  .Flush_Done (Flush_Done), // out
  .In_Valid (In_Valid), // in
  .In_Data (In_Data), // in
  .In_Last (In_Last), // in
  .Out_Valid (Out_Valid), // out
  .Out_Data (Out_Data), // out
  .Out_Last (Out_Last) // out
);

endmodule

`default_nettype wire

