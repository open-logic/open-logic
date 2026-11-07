`default_nettype none

module olo_fix_lin_approx_calc_sv
 #(
   parameter string InFmt_g,
   parameter string OutFmt_g,
   parameter string OffsFmt_g,
   parameter string GradFmt_g,
   parameter  TableSize_g,
   parameter  TableLatency_g,
   parameter string Round_g = olo_fix_sv_pkg::FixRound_NonSymPos_c,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_Sat_c)
  (
   input wire Clk,
   input wire Rst,
   input wire In_Valid = '1,
   input wire [olo_fix_sv_pkg::fixFmtFromString(InFmt_g)-1: 0] In_Data,
   output logic Out_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(OutFmt_g)-1: 0] Out_Result,
   output logic [olo_fix_sv_pkg::fixFmtFromString(TableSize_g)-1: 0] Tbl_Addr,
   input wire Tbl_Data
  );

  // very shallow wrapper
olo_fix_lin_approx_calc
 #(
  .InFmt_g (InFmt_g),
  .OutFmt_g (OutFmt_g),
  .OffsFmt_g (OffsFmt_g),
  .GradFmt_g (GradFmt_g),
  .TableSize_g (TableSize_g),
  .TableLatency_g (TableLatency_g),
  .Round_g (Round_g),
  .Saturate_g (Saturate_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Valid (In_Valid), // in
  .In_Data (In_Data), // in
  .Out_Valid (Out_Valid), // out
  .Out_Result (Out_Result), // out
  .Tbl_Addr (Tbl_Addr), // out
  .Tbl_Data (Tbl_Data) // in
);

endmodule

`default_nettype wire

