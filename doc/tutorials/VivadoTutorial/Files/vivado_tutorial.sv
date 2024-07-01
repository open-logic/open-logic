
module vivado_tutorial (
    input wire Clk,
    input wire [1:0] Buttons,
    input wire [3:0] Switches,
    output wire [3:0] Led
);

    // Signal Declarations
    reg [1:0] Buttons_Sync;
    reg [3:0] Switches_Sync;
    reg [1:0] RisingEdges;
    reg [1:0] Buttons_Last;
    reg Rst = 1'b1;
    reg [1:0] RstPipe = 2'b11;

    // Assert reset after power up
    always @(posedge Clk) begin
        Rst <= RstPipe[1];
        RstPipe <= {RstPipe[0], 1'b0};
    end

    // Debounce Buttons
    olo_intf_debounce #(
        .ClkFrequency_g(125.0e6),
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
        .ClkFrequency_g(125.0e6),
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
    olo_base_fifo_sync #(
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