`default_nettype none

module olo_fix_compare_sv
 #(
   parameter string AFmt_g,
   parameter string BFmt_g,
   parameter string Comparison_g,
   parameter  OpRegs_g = 1)
  (
   input wire Clk = '0,
   input wire Rst = '0,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] In_A,
   input wire [olo_fix_sv_pkg::fixFmtFromString(BFmt_g)-1: 0] In_B,
   output logic Out_Valid,
   output logic Out_Result
  );

  // very shallow wrapper
olo_fix_compare
 #(
  .AFmt_g (AFmt_g),
  .BFmt_g (BFmt_g),
  .Comparison_g (Comparison_g),
  .OpRegs_g (OpRegs_g))
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

