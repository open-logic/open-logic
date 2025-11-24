---------------------------------------------------------------------------------------------------
-- Copyright (c) 2024-2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_rate_limit_tb is
    generic (
        runner_cfg      : string;
        Width_g         : positive := 16;
        RegisterReady_g : boolean  := false;
        Mode_g          : string   := "BLOCK";
        Period_g        : positive := 10;
        MaxSamples_g    : positive := 2;
        RandomStall_g   : boolean  := false
    );
end entity;

architecture sim of olo_base_rate_limit_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : integer := Width_g;

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;
    
    -- Rate limiting calculations
    constant ExpectedTimePerTransfer_c : time := (real(Period_g) / real(MaxSamples_g)) * Clk_Period_c;
    constant Tolerance_c              : time := (real(Period_g + 2)) * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- Shared Variables for Throughput Measurement
    -----------------------------------------------------------------------------------------------
    shared variable ThroughputStart_v     : time    := 0 ns;
    shared variable ThroughputEnd_v       : time    := 0 ns;
    shared variable ThroughputSamples_v   : integer := 0;
    shared variable ThroughputActive_v    : boolean := false;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => DataWidth_c,
        stall_config => new_stall_config(choose(RandomStall_g, 0.3, 0.0), 0, 2*Period_g)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => DataWidth_c,
        stall_config => new_stall_config(choose(RandomStall_g, 0.3, 0.0), 0, 2*Period_g)
    );

    -----------------------------------------------------------------------------------------------
    -- Test Helper Procedures
    -----------------------------------------------------------------------------------------------
    procedure PushData (
        signal net : inout network_t;
        constant NumSamples : integer;
        constant StartValue : integer := 0;
        constant DelayBetweenSamples : time := 0 ns
    ) is
    begin
        for i in 0 to NumSamples - 1 loop
            push_axi_stream(net, AxisMaster_c, toUslv(StartValue + i, DataWidth_c));
            -- Wait between samples to simulate slower input rate (if requested)
            if DelayBetweenSamples > 0 ns then
                wait for DelayBetweenSamples;
            end if;
        end loop;
    end procedure;



    procedure CheckData (
        signal net : inout network_t;
        constant NumSamples : integer;
        constant StartValue : integer := 0;
        constant DelayBetweenSamples : time := 0 ns
    ) is
    begin
        for i in 0 to NumSamples - 1 loop
            check_axi_stream(net, AxisSlave_c, toUslv(StartValue + i, DataWidth_c), 
                           blocking => false, 
                           msg => "Sample " & integer'image(i) & " (value " & integer'image(StartValue + i) & ")");
            if DelayBetweenSamples > Clk_Period_c then
                -- A little bit less (1 ns less) to compensate for delta cycle.
                wait for DelayBetweenSamples; -- Adjust for clock period already waited in check_axi_stream
            end if;
        end loop;
    end procedure;

    procedure CheckTiming (
        constant StartTime : time;
        constant EndTime : time;
        constant ExpectedDuration : time
    ) is
        variable ActualDuration_v : time;
    begin
        ActualDuration_v := EndTime - StartTime;
        -- Check within tolerance normally
        if not RandomStall_g then
            check(abs(ActualDuration_v - ExpectedDuration) <= Tolerance_c,
                  "Timing check failed. Expected: " & time'image(ExpectedDuration) & 
                  ", Actual: " & time'image(ActualDuration_v) & 
                  ", Tolerance: ±" & time'image(Tolerance_c));
        end if;
        -- Duration may be higher with random stalls
        if RandomStall_g then
            check(ActualDuration_v >= ExpectedDuration,
                  "Timing check failed. Actual duration " & time'image(ActualDuration_v) & 
                  " is less than expected minimum " & time'image(ExpectedDuration));
        end if;
    end procedure;

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk       : std_logic                                     := '0';
    signal Rst       : std_logic                                     := '0';
    signal In_Data   : std_logic_vector(DataWidth_c - 1 downto 0)    := (others => '0');
    signal In_Valid  : std_logic                                     := '0';
    signal In_Ready  : std_logic                                     := '0';
    signal Out_Data  : std_logic_vector(DataWidth_c - 1 downto 0)    := (others => '0');
    signal Out_Valid : std_logic                                     := '0';
    signal Out_Ready : std_logic                                     := '0';

    -- Burst size detection
    signal MaxBurstSize : integer := 0;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
        variable ExpectedRate_v : real;
        variable ActualRate_v   : real;
        variable NumSamples_v   : integer;
        -- Variables for timing tests
        variable InputDelay_v : time;
        variable OutputDelay_v : time;
        variable StartTime_v : time;
        variable EndTime_v : time;
        variable ExpectedDuration_v : time;
        -- Test size
        variable NumSamples_c : positive := MaxSamples_g * 20;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset DUT
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("Reset") then
                -- Check initial state after reset
                check_equal(Out_Valid, '0', "Out_Valid should be '0' after reset");
                
                -- Check In_Ready behavior based on RegisterReady_g
                -- Note: Out_Ready is driven by VC and will be '0' during reset
                if RegisterReady_g then
                    -- When RegisterReady_g=true, In_Ready should be registered and thus '1' after reset
                    check_equal(In_Ready, '1', "In_Ready should be '1' after reset when RegisterReady_g=true");
                else
                    -- When RegisterReady_g=false, In_Ready is directly connected to Out_Ready (which is '0' from VC)
                    check_equal(In_Ready, '0', "In_Ready should be '0' after reset when RegisterReady_g=false (follows Out_Ready)");
                end if;
                
            elsif run("DataCorrectness") then
                -- Test data integrity through the entity without timing constraints        
                
                -- Push data (non-blocking, let rate limiter handle the flow)
                PushData(net, NumSamples_c, 16#1000#);
                
                -- Check data (blocking, wait for all samples to come through)
                CheckData(net, NumSamples_c, 16#1000#);

            elsif run("SlowInput") then
                -- Test case 1: Input provided at 2x lower rate than allowed
                InputDelay_v := 2.0 * ExpectedTimePerTransfer_c; -- 2x slower input
                
                -- Expected duration: limited by input rate since it's slower than rate limit
                ExpectedDuration_v := real(NumSamples_c) * InputDelay_v;
                
                StartTime_v := now;
                CheckData(net, NumSamples_c, 16#2000#); -- Check non-blocking first, then push blocking
                PushData(net, NumSamples_c, 16#2000#, InputDelay_v);
                EndTime_v := now;
                
                CheckTiming(StartTime_v, EndTime_v, ExpectedDuration_v);

            elsif run("SlowOutput") then  
                -- Test case 2: Output accepted at 2x lower rate than allowed
                OutputDelay_v := 2.0 * ExpectedTimePerTransfer_c; -- 2x slower output acceptance
                
                -- Expected duration: limited by output acceptance rate
                ExpectedDuration_v := real(NumSamples_c) * OutputDelay_v;
                
                StartTime_v := now;
                PushData(net, NumSamples_c, 16#3000#); -- push nonblocking, then check blocking
                CheckData(net, NumSamples_c, 16#3000#, OutputDelay_v);
                EndTime_v := now;
                
                CheckTiming(StartTime_v, EndTime_v, ExpectedDuration_v);

            elsif run("Throttled") then
                -- Test case 3: Data pushed through at full speed (rate limited)
                
                -- Expected duration: limited by rate limiter
                ExpectedDuration_v := real(NumSamples_c) * ExpectedTimePerTransfer_c;
                
                StartTime_v := now;
                PushData(net, NumSamples_c, 16#4000#);
                CheckData(net, NumSamples_c, 16#4000#);

                -- Wait until everything done
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));
                EndTime_v := now;

                -- Check burst behavior
                if Period_g > 1 then -- For Period_g = 1, there is no rate limiting and burst size is not defined
                    if Mode_g = "BLOCK" then
                        -- In BLOCK mode, maximum burst size should not exceed MaxSamples_g
                        check_equal(MaxBurstSize, MaxSamples_g,
                            "Maximum burst size " & integer'image(MaxBurstSize) & 
                            " exceeds MaxSamples_g " & integer'image(MaxSamples_g) & " in BLOCK mode");
                    elsif Mode_g = "SMOOTH" and MaxSamples_g*2 < Period_g then
                        -- In SMOOTH mode, maximum burst size should not exceed 1
                        check_equal(MaxBurstSize, 1,
                            "Maximum burst size " & integer'image(MaxBurstSize) & 
                            " exceeds 1 in SMOOTH mode");
                    end if;
                end if;
                
                -- Check Timing
                CheckTiming(StartTime_v, EndTime_v, ExpectedDuration_v);
                
            end if;

            -- Wait for all verification components to be idle
            wait for 1 us;
            wait_until_idle(net, as_sync(AxisSlave_c));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
            -- Report maximum burst size
            report "Maximum burst size detected on output: " & integer'image(MaxBurstSize);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Throughput Monitor
    -----------------------------------------------------------------------------------------------
    p_throughput_monitor : process (Clk) is
    begin
        if rising_edge(Clk) then
            -- Count samples that pass through successfully
            if ThroughputActive_v and Out_Valid = '1' and Out_Ready = '1' then
                ThroughputSamples_v := ThroughputSamples_v + 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Maximum Burst Size Detector
    -----------------------------------------------------------------------------------------------
    p_burst_monitor : process (Clk) is
        variable BurstSize : integer := 0;
        variable FirstBurst : boolean := true;
    begin
        if rising_edge(Clk) then
            if Rst = '1' then
                BurstSize := 0;
                MaxBurstSize <= 0;
                FirstBurst := true;
            elsif Out_Valid = '1' and Out_Ready = '1' then
                BurstSize := BurstSize + 1;
                if BurstSize > MaxBurstSize then
                    MaxBurstSize <= BurstSize;
                end if;
            elsif Out_Valid = '0' or Out_Ready = '0' then
                BurstSize := 0;
                -- Ignore first burst (might be affected by transients
                if FirstBurst and MaxBurstSize > 0 then
                    MaxBurstSize <= 0;
                    FirstBurst := false;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock Generation
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * Clk_Period_c;

    -----------------------------------------------------------------------------------------------
    -- DUT Instantiation
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_rate_limit
        generic map (
            Width_g         => Width_g,
            RegisterReady_g => RegisterReady_g,
            Mode_g          => Mode_g,
            Period_g        => Period_g,
            MaxSamples_g    => MaxSamples_g
        )
        port map (
            Clk       => Clk,
            Rst       => Rst,
            In_Data   => In_Data,
            In_Valid  => In_Valid,
            In_Ready  => In_Ready,
            Out_Data  => Out_Data,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk   => Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => In_Data
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data
        );

end architecture;