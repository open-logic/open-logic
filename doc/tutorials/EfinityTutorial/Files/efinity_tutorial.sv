
module efinity_tutorial (
    input wire Clk,
    input wire [1:0] Buttons,
    input wire [3:0] Switches,
    output wire [3:0] Led
);

    // Signal Declarations
    wire [1:0] Buttons_Sync;
    wire [3:0] Switches_Sync;
    wire [3:0] Led_Sig;
    reg [1:0] Buttons_Inv;
    reg [1:0] RisingEdges;
    reg [1:0] Buttons_Last;
    wire Rst;

    // Assert reset after power up
    olo_base_reset_gen i_reset (                  
        .Clk(Clk),
        .RstOut(Rst)
    );  

    // Debounce Buttons
    olo_intf_debounce #(
        .ClkFrequency_g(50.0e6),
        .DebounceTime_g(25.0e-3),
        .Width_g(2)
    ) i_buttons (
        .Clk(Clk),
        .Rst(Rst),
        .DataAsync(Buttons),
        .DataOut(Buttons_Sync)
    );

    // Debounce Buttons
    olo_intf_debounce #(
        .ClkFrequency_g(50.0e6),
        .DebounceTime_g(25.0e-3),
        .Width_g(4)
    ) i_switches (
        .Clk(Clk),
        .Rst(Rst),
        .DataAsync(Switches),
        .DataOut(Switches_Sync)
    );

    // -- Edge Detection
    always @(posedge Clk) begin
        if (Rst) begin
            Buttons_Inv <= 2'b00;
            Buttons_Last <= 2'b00;
            RisingEdges <= 2'b00;
        end else begin
            Buttons_Inv <= ~Buttons_Sync;
            RisingEdges <= Buttons_Inv & ~Buttons_Last;
            Buttons_Last <= Buttons_Inv;
        end
    end

    // FIFO
    olo_base_fifo_sync #(
        .Width_g(4),
        .Depth_g(4096)
    ) i_fifo (
        .Clk(Clk),
        .Rst(Rst),
        .In_Data(Switches_Sync),
        .In_Valid(RisingEdges[0]),
        .Out_Data(Led_Sig),
        .Out_Ready(RisingEdges[1])
    );
    assign Led = ~Led_Sig;

endmodule
