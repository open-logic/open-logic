`default_nettype none

module olo_fix_mix_r2c_sv
 #(
   parameter string InFmt_g,
   parameter string MixFmt_g,
   parameter string OutFmt_g,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter  MultRegs_g = 1)
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_SigReal,
   input wire [olo_fix_sv_pkg::fixFmtFromString(MixFmt_g)-1: 0] In_MixI,
   input wire [olo_fix_sv_pkg::fixFmtFromString(MixFmt_g)-1: 0] In_MixQ,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_I,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Q
  );

  // very shallow wrapper
olo_fix_mix_r2c
 #(
  .InFmt_g (InFmt_g),
  .MixFmt_g (MixFmt_g),
  .OutFmt_g (OutFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .MultRegs_g (MultRegs_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_SigReal (In_SigReal), // in
  .In_MixI (In_MixI), // in
  .In_MixQ (In_MixQ), // in
  .Out_Valid (Out_Valid), // out
  .Out_I (Out_I), // out
  .Out_Q (Out_Q) // out
);

endmodule

`default_nettype wire

