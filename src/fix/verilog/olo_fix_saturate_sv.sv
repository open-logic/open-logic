`default_nettype none

module olo_fix_saturate_sv
 #(
   parameter string AFmt_g,
   parameter string ResultFmt_g,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Sat_c,
   parameter string SatReg_g = "YES")
  (
   input wire Clk = '0,
   input wire Rst = '0,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(AFmt_g)-1: 0] In_A,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_Result
  );

  // very shallow wrapper
olo_fix_saturate
 #(
  .AFmt_g (AFmt_g),
  .ResultFmt_g (ResultFmt_g),
  .Saturate_g (Saturate_g),
  .SatReg_g (SatReg_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_A (In_A), // in
  .Out_Valid (Out_Valid), // out
  .Out_Result (Out_Result) // out
);

endmodule

`default_nettype wire

