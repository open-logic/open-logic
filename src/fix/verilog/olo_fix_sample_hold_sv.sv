`default_nettype none

module olo_fix_sample_hold_sv
 #(
   parameter string Fmt_g,
   parameter real ResetValue_g = 0.0,
   parameter  ResetValid_g = 1)
  (
   input wire Clk,
   input wire Rst,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] In_Data,
   input wire In_Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] Out_Data,
   output logic Out_Valid
  );

  // very shallow wrapper
olo_fix_sample_hold
 #(
  .Fmt_g (Fmt_g),
  .ResetValue_g (ResetValue_g),
  .ResetValid_g (ResetValid_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .In_Data (In_Data), // in
  .In_Valid (In_Valid), // in
  .Out_Data (Out_Data), // out
  .Out_Valid (Out_Valid) // out
);

endmodule

`default_nettype wire

