`default_nettype none

module olo_fix_cplx_addsub_sv
 #(
   parameter string AFmt_g,
   parameter string BFmt_g,
   parameter string ResultFmt_g,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter string IqHandling_g = "Parallel",
   parameter string Operation_g = "Add",
   parameter  OpRegs_g = 1,
   parameter string RoundReg_g = "YES",
   parameter string SatReg_g = "YES")
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] InA_I,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] InA_Q,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] InA_IQ,
   input wire [olo_fix_sv_pkg::fixFmtFromString(BFmt_g)-1: 0] InB_I,
   input wire [olo_fix_sv_pkg::fixFmtFromString(BFmt_g)-1: 0] InB_Q,
   input wire [olo_fix_sv_pkg::fixFmtFromString(BFmt_g)-1: 0] InB_IQ,
   input wire In_Last = '0,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_I,
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_Q,
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_IQ,
   output logic Out_Last
  );

  // very shallow wrapper
olo_fix_cplx_addsub
 #(
  .AFmt_g (AFmt_g),
  .BFmt_g (BFmt_g),
  .ResultFmt_g (ResultFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .IqHandling_g (IqHandling_g),
  .Operation_g (Operation_g),
  .OpRegs_g (OpRegs_g),
  .RoundReg_g (RoundReg_g),
  .SatReg_g (SatReg_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .InA_I (InA_I), // in
  .InA_Q (InA_Q), // in
  .InA_IQ (InA_IQ), // in
  .InB_I (InB_I), // in
  .InB_Q (InB_Q), // in
  .InB_IQ (InB_IQ), // in
  .In_Last (In_Last), // in
  .Out_Valid (Out_Valid), // out
  .Out_I (Out_I), // out
  .Out_Q (Out_Q), // out
  .Out_IQ (Out_IQ), // out
  .Out_Last (Out_Last) // out
);

endmodule

`default_nettype wire

