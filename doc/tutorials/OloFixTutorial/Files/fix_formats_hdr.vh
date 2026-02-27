// Header Guards
`ifndef fix_formats_hdr_SVH
`define fix_formats_hdr_SVH
	
package fix_formats_hdr;

    // Constants
    
    localparam string FmtIn_c = "(1, 3, 8)";
    
    localparam string FmtOut_c = "(1, 3, 8)";
    
    localparam string FmtKp_c = "(0, 8, 4)";
    
    localparam string FmtKi_c = "(0, 4, 4)";
    
    localparam string FmtIlim_c = "(0, 4, 4)";
    
    localparam string FmtIlimNeg_c = "(1, 4, 4)";
    
    localparam string FmtErr_c = "(1, 4, 8)";
    
    localparam string FmtPpart_c = "(1, 3, 8)";
    
    localparam string FmtImult_c = "(1, 8, 12)";
    
    localparam string FmtIadd_c = "(1, 9, 12)";
    
    localparam string FmtI_c = "(1, 4, 12)";
    
    localparam int FmtIn_w = 12;
    
    localparam int FmtOut_w = 12;
    
    localparam int FmtKp_w = 12;
    
    localparam int FmtKi_w = 8;
    
    localparam int FmtIlim_w = 8;
    
    localparam int FmtIlimNeg_w = 9;
    
    localparam int FmtErr_w = 13;
    
    localparam int FmtPpart_w = 12;
    
    localparam int FmtImult_w = 21;
    
    localparam int FmtIadd_w = 22;
    
    localparam int FmtI_w = 17;
    

    // Vectors
    

endpackage : fix_formats_hdr

`endif // fix_formats_hdr_SVH
