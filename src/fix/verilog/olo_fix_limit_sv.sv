`default_nettype none

module olo_fix_limit_sv
 #(
   parameter string InFmt_g,
   parameter string LimLoFmt_g = "(1,1,1)",
   parameter string LimHiFmt_g = "(1,1,1)",
   parameter string ResultFmt_g,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter  UseFixedLimits_g = 0,
   parameter real FixedLimLo_g = 0.0,
   parameter real FixedLimHi_g = 0.0,
   parameter string RoundReg_g = "YES",
   parameter string SatReg_g = "YES")
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   input wire [olo_fix_sv_pkg::fixFmtFromString(LimLoFmt_g)-1: 0] In_LimLo,
   input wire [olo_fix_sv_pkg::fixFmtFromString(LimHiFmt_g)-1: 0] In_LimHi,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_Result
  );

  // very shallow wrapper
olo_fix_limit
 #(
  .InFmt_g (InFmt_g),
  .LimLoFmt_g (LimLoFmt_g),
  .LimHiFmt_g (LimHiFmt_g),
  .ResultFmt_g (ResultFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .UseFixedLimits_g (UseFixedLimits_g),
  .FixedLimLo_g (FixedLimLo_g),
  .FixedLimHi_g (FixedLimHi_g),
  .RoundReg_g (RoundReg_g),
  .SatReg_g (SatReg_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_Data (In_Data), // in
  .In_LimLo (In_LimLo), // in
  .In_LimHi (In_LimHi), // in
  .Out_Valid (Out_Valid), // out
  .Out_Result (Out_Result) // out
);

endmodule

`default_nettype wire

