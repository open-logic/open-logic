module libero_tutorial (
    input wire Clk,
    input wire [3:0] Switches,
    output wire [3:0] Led
);

    // Signal Declarations
    wire [3:0] Switches_Inv;
    wire [3:0] Switches_Sync;
    reg [3:0] Data;
    reg [2:0] RisingEdges;
    reg [2:0] Events;
    reg [2:0] Events_Last;
    wire Rst;

    // Assert reset after power up
    olo_base_reset_gen #(
        .RstInPolarity_g(1'b0)
    ) i_reset (                  
        .Clk(Clk),
        .RstIn(Switches[3]),
        .RstOut(Rst)
    );  

    // Debounce Switches
    assign Switches_Inv = ~Switches;
    olo_intf_debounce #(
        .ClkFrequency_g(50.0e6),
        .DebounceTime_g(25.0e-3),
        .Width_g(4)
    ) i_switches (
        .Clk(Clk),
        .Rst(Rst),
        .DataAsync(Switches_Inv),
        .DataOut(Switches_Sync)
    );

    // Switch(3) is used for reset
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
        .Out_Data(Led),
        .Out_Ready(RisingEdges[1])
    );

endmodule