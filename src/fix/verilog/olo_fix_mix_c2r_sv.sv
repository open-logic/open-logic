`default_nettype none

module olo_fix_mix_c2r_sv
 #(
   parameter string InFmt_g,
   parameter string MixFmt_g,
   parameter string OutFmt_g,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter  MultRegs_g = 1,
   parameter string IqHandling_g = "Parallel")
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_SigI,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_SigQ,
   input wire [olo_fix_sv_pkg::fixFmtFromString(MixFmt_g)-1: 0] In_MixI,
   input wire [olo_fix_sv_pkg::fixFmtFromString(MixFmt_g)-1: 0] In_MixQ,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_SigIQ,
   input wire [olo_fix_sv_pkg::fixFmtFromString(MixFmt_g)-1: 0] In_MixIQ,
   input wire In_Last = '0,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_SigReal
  );

  // very shallow wrapper
olo_fix_mix_c2r
 #(
  .InFmt_g (InFmt_g),
  .MixFmt_g (MixFmt_g),
  .OutFmt_g (OutFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .MultRegs_g (MultRegs_g),
  .IqHandling_g (IqHandling_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_SigI (In_SigI), // in
  .In_SigQ (In_SigQ), // in
  .In_MixI (In_MixI), // in
  .In_MixQ (In_MixQ), // in
  .In_SigIQ (In_SigIQ), // in
  .In_MixIQ (In_MixIQ), // in
  .In_Last (In_Last), // in
  .Out_Valid (Out_Valid), // out
  .Out_SigReal (Out_SigReal) // out
);

endmodule

`default_nettype wire

