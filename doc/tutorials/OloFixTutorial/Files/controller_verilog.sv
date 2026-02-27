
`include "fix_formats_hdr.vh"
import fix_formats_hdr::*;

module olo_fix_tutorial_controller (
    input wire Clk,
    input wire Rst,
    input wire [FmtKi_w-1:0] Cfg_Ki,
    input wire [FmtKp_w-1:0] Cfg_Kp,
    input wire [FmtIlim_w-1:0] Cfg_ILim,
    input wire In_Valid,
    input wire [FmtIn_w-1:0] In_Actual,
    input wire [FmtIn_w-1:0] In_Target,
    output wire Out_Valid,
    output wire [FmtOut_w-1:0] Out_Result
);

    // Static Signals
    wire [FmtIlimNeg_w-1:0] ILimNeg;

    // Dynamic Signals
    wire [FmtErr_w-1:0] Error;
    wire Error_Valid;
    wire [FmtPpart_w-1:0] Ppart;
    wire Ppart_Valid;
    wire [FmtImult_w-1:0] I1;
    wire I1_Valid;
    wire [FmtIadd_w-1:0] IPresat;
    wire IPresat_Valid;
    wire [FmtI_w-1:0] ILimited;
    wire ILimited_Valid;
    reg [FmtI_w-1:0] Integrator;
    reg Integrator_Valid;

    //--------------------------------------------
    // Static Calculations
    //--------------------------------------------
    \olo.olo_fix_neg #(                  
        .AFmt_g(FmtIlim_c),
        .ResultFmt_g(FmtIlimNeg_c)
    ) i_ilim_neg (
        .Clk(Clk),
        .Rst(Rst),
        .In_A(Cfg_ILim),
        .Out_Result(ILimNeg)
    );

    //--------------------------------------------
    // Dynamic Calculations
    //--------------------------------------------

    // Error Calculation
    \olo.olo_fix_sub #(                  
        .AFmt_g(FmtIn_c),
        .BFmt_g(FmtIn_c),
        .ResultFmt_g(FmtErr_c)
    ) i_error_sub (
        .Clk(Clk),
        .Rst(Rst),
        .In_Valid(In_Valid),
        .In_A(In_Target),
        .In_B(In_Actual),
        .Out_Valid(Error_Valid),
        .Out_Result(Error)
    );

    // P Part 
    \olo.olo_fix_mult #(                  
        .AFmt_g(FmtErr_c),
        .BFmt_g(FmtKp_c),
        .OpRegs_g(8),
        .ResultFmt_g(FmtPpart_c),
        .Round_g("NonSymPos_s"),
        .Saturate_g("Sat_s")
    ) i_p_mult (
        .Clk(Clk),
        .Rst(Rst),
        .In_Valid(Error_Valid),
        .In_A(Error),
        .In_B(Cfg_Kp),
        .Out_Valid(Ppart_Valid),
        .Out_Result(Ppart)
    );

    // I Part
    \olo.olo_fix_mult #(                  
        .AFmt_g(FmtErr_c),
        .BFmt_g(FmtKi_c),
        .ResultFmt_g(FmtImult_c)
    ) i_i_mult (
        .Clk(Clk),
        .Rst(Rst),
        .In_Valid(Error_Valid),
        .In_A(Error),
        .In_B(Cfg_Ki),
        .Out_Valid(I1_Valid),
        .Out_Result(I1)
    );

    \olo.olo_fix_add #(                  
        .AFmt_g(FmtI_c),
        .BFmt_g(FmtImult_c),
        .ResultFmt_g(FmtIadd_c)
    ) i_i_add (
        .Clk(Clk),
        .Rst(Rst),
        .In_Valid(I1_Valid),
        .In_A(Integrator),
        .In_B(I1),
        .Out_Valid(IPresat_Valid),
        .Out_Result(IPresat)
    );

    \olo.olo_fix_limit #(                  
        .InFmt_g(FmtIadd_c),
        .LimLoFmt_g(FmtIlimNeg_c),
        .LimHiFmt_g(FmtIlim_c),
        .ResultFmt_g(FmtI_c)
    ) i_limit (
        .Clk(Clk),
        .Rst(Rst),
        .In_Valid(IPresat_Valid),
        .In_Data(IPresat),
        .In_LimLo(ILimNeg),
        .In_LimHi(Cfg_ILim),
        .Out_Valid(ILimited_Valid),
        .Out_Result(ILimited)
    );

    always @(posedge Clk) begin
        // Normal Operation
        if (ILimited_Valid) begin
            Integrator <= ILimited;
        end
        Integrator_Valid <= ILimited_Valid;
        // Reset
        if (Rst) begin
            Integrator <= 17'b0;
            Integrator_Valid <= 1'b0;
        end
    end

    // Output Adder
    \olo.olo_fix_add #(                  
        .AFmt_g(FmtI_c),
        .BFmt_g(FmtPpart_c),
        .ResultFmt_g(FmtOut_c),
        .Round_g("NonSymPos_s"),
        .Saturate_g("Sat_s")
    ) i_out_add (
        .Clk(Clk),
        .Rst(Rst),
        .In_Valid(ILimited_Valid),
        .In_A(ILimited),
        .In_B(Ppart),
        .Out_Valid(Out_Valid),
        .Out_Result(Out_Result)
    );

endmodule
