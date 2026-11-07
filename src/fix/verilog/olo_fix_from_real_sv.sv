`default_nettype none

module olo_fix_from_real_sv
 #(
   parameter string ResultFmt_g,
   parameter string Saturate_g = olo_fix_sv_pkg::FixSaturate_SatWarn_c,
   parameter real Value_g = 0.0)
  (
   output logic [olo_fix_sv_pkg::fixFmtFromString(ResultFmt_g)-1: 0] Out_Value
  );

  // very shallow wrapper
olo_fix_from_real
 #(
  .ResultFmt_g (ResultFmt_g),
  .Saturate_g (Saturate_g),
  .Value_g (Value_g))
inst (
  .Out_Value (Out_Value) // out
);

endmodule

`default_nettype wire

