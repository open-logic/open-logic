`default_nettype none

module olo_fix_add_sv
 #(
   parameter string AFmt_g,
   parameter string BFmt_g,
   parameter string ResultFmt_g,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_Trunc_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Warn_c,
   parameter  OpRegs_g = 1,
   parameter string RoundReg_g = "YES",
   parameter string SatReg_g = "YES")
  (
   input wire Clk = '0,
   input wire Rst = '0,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] In_A,
   input wire [olo_fix_sv_pkg::fixFmtFromString(BFmt_g)-1: 0] In_B,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_Result
  );

  // very shallow wrapper
olo_fix_add
 #(
  .AFmt_g (AFmt_g),
  .BFmt_g (BFmt_g),
  .ResultFmt_g (ResultFmt_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g),
  .OpRegs_g (OpRegs_g),
  .RoundReg_g (RoundReg_g),
  .SatReg_g (SatReg_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_A (In_A), // in
  .In_B (In_B), // in
  .Out_Valid (Out_Valid), // out
  .Out_Result (Out_Result) // out
);

endmodule

`default_nettype wire

