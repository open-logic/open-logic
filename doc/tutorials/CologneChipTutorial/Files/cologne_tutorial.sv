module cologne_tutorial (
    input wire Clk,
    input wire [2:0] Switches,
    output wire [3:0] Led
);

    // Signal Declarations
    wire [2:0] Switches_Sync;
    reg [3:0] Data;
    reg [2:0] RisingEdges;
    reg [2:0] Events;
    reg [2:0] Events_Last;
    wire [2:0] Led_Int;
    wire Rst;

    // Assert reset after power up
    olo_base_reset i_reset (                  
        .Clk(Clk),
        .RstOut(Rst)
    );  

    // Debounce Switches
    olo_intf_debounce #(
        .ClkFrequency_g(10.0e6),
        .DebounceTime_g(25.0e-3),
        .Width_g(4)
    ) i_switches (
        .Clk(Clk),
        .Rst(Rst),
        .DataAsync(Switches),
        .DataOut(Switches_Sync)
    );

    assign Events = Switches_Sync[2:0];

    // -- Edge Detection
    always @(posedge Clk) begin
        if (Rst) begin
            Events_Last <= 2'b000;
            RisingEdges <= 2'b000;
        end else begin
            RisingEdges <= Events & ~Events_Last;
            Events_Last <= Events;
        end
    end

    //Data is emulate through a counter incremented by button press on switch(2)
    // .. because of lack of available switches/buttons  
    always @(posedge Clk) begin
        if (Rst) begin
            Data <= 4'b0000;
        end else if (RisingEdges[2]) begin
            Data <= Data + 1;
        end
    end

    // FIFO
    olo_base_fifo_sync #(
        .Width_g(4),
        .Depth_g(4096)
    ) i_fifo (
        .Clk(Clk),
        .Rst(Rst),
        .In_Data(Data),
        .In_Valid(RisingEdges[0]),
        .Out_Data(Led_Int),
        .Out_Ready(RisingEdges[1])
    );

    assign Led = ~Led_Int;

endmodule