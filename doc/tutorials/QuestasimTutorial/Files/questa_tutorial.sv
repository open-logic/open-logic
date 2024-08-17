
module questa_tutorial (
    input wire Clk,
    input wire [1:0] Buttons,
    input wire [3:0] Switches,
    output wire [3:0] Led
);

    // Signal Declarations
    wire [1:0] Buttons_Sync;
    wire [3:0] Switches_Sync;
    reg [1:0] RisingEdges;
    reg [1:0] Buttons_Last;
    wire Rst;

    // Assert reset after power up
    \olo.olo_base_reset_gen i_reset (                  
        .Clk(Clk),
        .RstOut(Rst)
    );  

    // Debounce Buttons
    \olo.olo_intf_debounce #(
        .ClkFrequency_g(100.0e3),
        .DebounceTime_g(25.0e-3),
        .Width_g(2)
    ) i_buttons (
        .Clk(Clk),
        .Rst(Rst),
        .DataAsync(Buttons),
        .DataOut(Buttons_Sync)
    );

    // Debounce Buttons
    \olo.olo_intf_debounce #(
        .ClkFrequency_g(100.0e3),
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
            Buttons_Last <= 2'b00;
            RisingEdges <= 2'b00;
        end else begin
            RisingEdges <= Buttons_Sync & ~Buttons_Last;
            Buttons_Last <= Buttons_Sync;
        end
    end

    // FIFO
    \olo.olo_base_fifo_sync #(
        .Width_g(4),
        .Depth_g(4096)
    ) i_fifo (
        .Clk(Clk),
        .Rst(Rst),
        .In_Data(Switches_Sync),
        .In_Valid(RisingEdges[0]),
        .Out_Data(Led),
        .Out_Ready(RisingEdges[1])
    );

endmodule
