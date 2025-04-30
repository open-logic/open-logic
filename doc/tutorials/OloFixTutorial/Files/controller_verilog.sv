
module olo_fix_tutorial_controller (
    input wire Clk,
    input wire Rst,
    input wire [7:0] Cfg_Ki,    // (0, 4, 4)
    input wire [11:0] Cfg_Kp,   // (0, 8, 4)
    input wire [7:0] Cfg_ILim,  // (0, 4, 4)
    input wire In_Valid,
    input wire [11:0] In_Actual, // (1, 3, 8)
    input wire [11:0] In_Target, // (1, 3, 8)
    output wire Out_Valid,
    output wire [11:0] Out_Result // (1, 3, 8)
);

    // Static Signals
    wire [8:0] ILimNeg; // (1, 4, 4)

    // Dynamic Signals
    wire [12:0] Error; // (1, 4, 8)
    wire Error_Valid;
    wire [11:0] Ppart; // (1, 3, 8)
    wire Ppart_Valid;
    wire [20:0] I1; // (1, 8, 12)
    wire I1_Valid;
    wire [21:0] IPresat; // (1, 9, 12)
    wire IPresat_Valid;
    wire [16:0] ILimited; // (1, 4, 12)
    wire ILimited_Valid;
    reg [16:0] Integrator; // (1, 9, 12)
    reg Integrator_Valid;

    // Formats
    localparam string FmtIn_c      = "(1, 3, 8)";
    localparam string FmtOut_c     = "(1, 3, 8)";
    localparam string FmtKp_c      = "(0, 8, 4)";
    localparam string FmtKi_c      = "(0, 4, 4)";
    localparam string FmtIlim_c    = "(0, 4, 4)";
    localparam string FmtIlimNeg_c = "(1, 4, 4)";
    localparam string FmtErr_c     = "(1, 4, 8)";
    localparam string FmtPpart_c   = "(1, 3, 8)";
    localparam string FmtImult_c   = "(1, 8, 12)";
    localparam string FmtIadd_c    = "(1, 9, 12)";
    localparam string FmtI_c       = "(1, 4, 12)";

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
