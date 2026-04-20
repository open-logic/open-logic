
module quartus_tutorial (
    input wire Clk,
	 input wire Rst,
	 input wire In_Valid,
	 output wire In_Ready,
	 input wire [16:0] In_I,
	 input wire [16:0] In_Q,
	 output wire Out_Valid,
	 output wire [15:0] Out_Mag,
	 output wire [15:0] Out_Ang
);

    olo_fix_cordic_vect 
    # (
        .InFmt_g           ("(1,0,16)" ),
        .OutMagFmt_g       ("(0,0,16)" ),
        .OutAngFmt_g       ("(0,0,16)" ),
        .IntXyFmt_g        ("AUTO"     ),
        .IntAngFmt_g       ("AUTO"     ),
        .Iterations_g      (16         ),
        .Mode_g            ("serial"),
        .GainCorrCoefFmt_g ("(0,0,17)" ),
        .Round_g           ("Trunc_s"  ),
        .Saturate_g        ("Sat_s"    )
    ) olo_fix_cordic_vect_inst
    (
     .Clk       (Clk),
     .Rst       (Rst),
     .In_Valid  (In_Valid),
     .In_Ready  (In_Ready),
     .In_I      (In_I),
     .In_Q      (In_Q),
     .Out_Valid (Out_Valid),
     .Out_Mag   (Out_Mag),
     .Out_Ang   (Out_Ang)
    );
   

endmodule
