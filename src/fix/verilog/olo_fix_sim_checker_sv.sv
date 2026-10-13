`default_nettype none

module olo_fix_sim_checker_sv
 #(
   parameter string FilePath_g,
   parameter  IsTimingMaster_g = 1,
   parameter string Fmt_g,
   parameter real StallProbability_g = 0.0,
   parameter  StallMaxCycles_g = 1,
   parameter  StallMinCycles_g = 1)
  (
   input wire Clk,
   input wire Ready,
   input wire Valid,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] Data
  );

  // very shallow wrapper
olo_fix_sim_checker
 #(
  .FilePath_g (FilePath_g),
  .IsTimingMaster_g (IsTimingMaster_g),
  .Fmt_g (Fmt_g),
  .StallProbability_g (StallProbability_g),
  .StallMaxCycles_g (StallMaxCycles_g),
  .StallMinCycles_g (StallMinCycles_g))
inst (
  .Clk (Clk), // in
  .Ready (Ready), // inout
  .Valid (Valid), // in
  .Data (Data) // in
);

endmodule

`default_nettype wire

