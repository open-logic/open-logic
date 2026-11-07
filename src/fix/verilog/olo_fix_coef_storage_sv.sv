`default_nettype none

module olo_fix_coef_storage_sv
 #(
   parameter  Depth_g,
   parameter string Fmt_g,
   parameter string Init_g = "0.0",
   parameter string StorageType_g = "ROM",
   parameter  RamReadback_g = 0,
   parameter string RamBehavior_g = "RBW",
   parameter  RdLatency_g = 1,
   parameter string MemStyle_g = "auto")
  (
   input wire Clk,
   input wire Rst,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Depth_g)-1: 0] Cfg_Addr,
   input wire Cfg_WrEna = '0,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] Cfg_WrData,
   input wire Cfg_RdEna = '0,
   output logic [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] Cfg_RdData,
   output logic Cfg_RdValid,
   input wire [olo_fix_sv_pkg::fixFmtFromString(Depth_g)-1: 0] Coef_Addr,
   input wire Coef_RdEna = '0,
   output logic [olo_fix_sv_pkg::fixFmtFromString(Fmt_g)-1: 0] Coef_RdData,
   output logic Coef_RdValid
  );

  // very shallow wrapper
olo_fix_coef_storage
 #(
  .Depth_g (Depth_g),
  .Fmt_g (Fmt_g),
  .Init_g (Init_g),
  .StorageType_g (StorageType_g),
  .RamReadback_g (RamReadback_g),
  .RamBehavior_g (RamBehavior_g),
  .RdLatency_g (RdLatency_g),
  .MemStyle_g (MemStyle_g))
inst (
  .Clk (Clk), // in
  .Rst (Rst), // in
  .Cfg_Addr (Cfg_Addr), // in
  .Cfg_WrEna (Cfg_WrEna), // in
  .Cfg_WrData (Cfg_WrData), // in
  .Cfg_RdEna (Cfg_RdEna), // in
  .Cfg_RdData (Cfg_RdData), // out
  .Cfg_RdValid (Cfg_RdValid), // out
  .Coef_Addr (Coef_Addr), // in
  .Coef_RdEna (Coef_RdEna), // in
  .Coef_RdData (Coef_RdData), // out
  .Coef_RdValid (Coef_RdValid) // out
);

endmodule

`default_nettype wire

