`default_nettype none

module olo_fix_sim_stimuli_sv
 #(
   parameter string FilePath_g,
   parameter  IsTimingMaster_g = 1,
   parameter string Fmt_g,
   parameter real StallProbability_g = 0.0,
   parameter  StallMaxCycles_g = 1,
   parameter  StallMinCycles_g = 1)
  (
   input wire Clk,
   input wire Rst,
   input wire Ready = '1,
   input wire Valid,
   output logic [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] Data
  );

  // very shallow wrapper
olo_fix_sim_stimuli
 #(
  .FilePath_g (FilePath_g),
  .IsTimingMaster_g (IsTimingMaster_g),
  .Fmt_g (Fmt_g),
  .StallProbability_g (StallProbability_g),
  .StallMaxCycles_g (StallMaxCycles_g),
  .StallMinCycles_g (StallMinCycles_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .Ready (Ready), // in
  .Valid (Valid), // inout
  .Data (Data) // out
);

endmodule

`default_nettype wire

