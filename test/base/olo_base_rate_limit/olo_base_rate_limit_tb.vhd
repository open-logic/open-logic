---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler
-- Authos: Oliver Bruendler
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
        RandomStall_g   : boolean  := false;
        RuntimeCfg_g    : boolean  := true
    );
end entity;

architecture sim of olo_base_rate_limit_tb is

    -----------------------------------------------------------------------------------------------
    -- TB Definitions
    -----------------------------------------------------------------------------------------------
    constant Clk_Frequency_c : real := 100.0e6;
    constant Clk_Period_c    : time := (1 sec) / Clk_Frequency_c;

    -- Parameters for runtime configuration
    type RtCfg_t is record
        Period     : positive;
        MaxSamples : positive;
    end record;
    type RtCfg_a is array (natural range <>) of RtCfg_t;

    constant RtCfgs_c : RtCfg_a := (
        (Period => 5, MaxSamples => 3),
        (Period => 5,  MaxSamples => 5),
        (Period => 1, MaxSamples => 1),
        (Period => 5, MaxSamples => 1),
        (Period => 3, MaxSamples => 2));

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length => Width_g,
        stall_config => new_stall_config(choose(RandomStall_g, 0.3, 0.0), 0, 2*Period_g)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length => Width_g,
        stall_config => new_stall_config(choose(RandomStall_g, 0.3, 0.0), 0, 2*Period_g)
    );

    -----------------------------------------------------------------------------------------------
    -- Test Helper Procedures
    -----------------------------------------------------------------------------------------------
    -- Push a number of samples into the rate limiter (optionally at a set rate)
    procedure pushData (
        signal net                   : inout network_t;
        constant NumSamples          : integer;
        constant StartValue          : integer := 0;
        constant DelayBetweenSamples : time    := 0 ns) is
    begin

        for i in 0 to NumSamples - 1 loop
            push_axi_stream(net, AxisMaster_c, toUslv(StartValue + i, Width_g));
            -- Wait between samples to simulate slower input rate (if requested)
            if DelayBetweenSamples > 0 ns then
                wait for DelayBetweenSamples;
            end if;
        end loop;

    end procedure;

    -- Check a number of samples from the rate limiter (optionally at a set rate)
    procedure checkData (
        signal net                   : inout network_t;
        constant NumSamples          : integer;
        constant StartValue          : integer := 0;
        constant DelayBetweenSamples : time    := 0 ns) is
    begin

        for i in 0 to NumSamples - 1 loop
            check_axi_stream(net, AxisSlave_c, toUslv(StartValue + i, Width_g),
                           blocking => false, msg => "Sample " & integer'image(i) & " (value " & integer'image(StartValue + i) & ")");
            if DelayBetweenSamples > Clk_Period_c then
                -- A little bit less (1 ns less) to compensate for delta cycle.
                wait for DelayBetweenSamples; -- Adjust for clock period already waited in check_axi_stream
            end if;
        end loop;

    end procedure;

    -- Check duration of the whole test-case.
    procedure checkTiming (
        constant StartTime        : time;
        constant EndTime          : time;
        constant ExpectedDuration : time;
        constant Tolerance        : time) is
        variable ActualDuration_v : time;
    begin
        ActualDuration_v := EndTime - StartTime;
        -- Check within tolerance normally
        if not RandomStall_g then
            check(abs(ActualDuration_v - ExpectedDuration) <= Tolerance,
                  "Timing check failed. Expected: " & time'image(ExpectedDuration) &
                  ", Actual: " & time'image(ActualDuration_v) &
                  ", Tolerance: ±" & time'image(Tolerance));
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
    signal Clk            : std_logic                                           := '0';
    signal Rst            : std_logic                                           := '0';
    signal In_Data        : std_logic_vector(Width_g - 1 downto 0)              := (others => '0');
    signal In_Valid       : std_logic                                           := '0';
    signal In_Ready       : std_logic                                           := '0';
    signal Out_Data       : std_logic_vector(Width_g - 1 downto 0)              := (others => '0');
    signal Out_Valid      : std_logic                                           := '0';
    signal Out_Ready      : std_logic                                           := '0';
    signal Cfg_MaxSamples : std_logic_vector(log2ceil(MaxSamples_g)-1 downto 0) := toUslv(MaxSamples_g-1, log2ceil(MaxSamples_g));
    signal Cfg_Period     : std_logic_vector(log2ceil(Period_g)-1 downto 0)     := toUslv(Period_g-1, log2ceil(Period_g));

    -- Burst size detection
    signal MaxBurstSize : integer := 0;
    signal RstBurstmeas : boolean := false;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 10 ms);

    p_control : process is
        -- Variables for timing tests
        variable Delay_v                   : time;
        variable StartTime_v               : time;
        variable EndTime_v                 : time;
        variable ExpectedDuration_v        : time;
        variable Cfg_v                     : RtCfg_t;
        -- Test size
        constant NumSamples_c              : positive := MaxSamples_g * 20;
        -- Rate limiting calculations
        variable ExpectedTimePerTransfer_v : time;
        variable Tolerance_v               : time;
    begin
        -- setup runner
        test_runner_setup(runner, runner_cfg);

        -- Run test suite
        while test_suite loop

            -- Reset DUT
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            -- Default values
            ExpectedTimePerTransfer_v := (real(Period_g) / real(MaxSamples_g)) * Clk_Period_c;
            Tolerance_v               := (real(Period_g + 2)) * Clk_Period_c;

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
                pushData(net, NumSamples_c, 16#1000#);

                -- Check data (blocking, wait for all samples to come through)
                checkData(net, NumSamples_c, 16#1000#);

            elsif run("SlowInput") then
                -- Test case 1: Input provided at 2x lower rate than allowed
                Delay_v := 2.0 * ExpectedTimePerTransfer_v; -- 2x slower input

                -- Expected duration: limited by input rate since it's slower than rate limit
                ExpectedDuration_v := real(NumSamples_c) * Delay_v;

                StartTime_v := now;
                checkData(net, NumSamples_c, 16#2000#); -- Check non-blocking first, then push blocking
                pushData(net, NumSamples_c, 16#2000#, Delay_v);
                EndTime_v   := now;

                checkTiming(StartTime_v, EndTime_v, ExpectedDuration_v, Tolerance_v);

            elsif run("SlowOutput") then
                -- Test case 2: Output accepted at 2x lower rate than allowed
                Delay_v := 2.0 * ExpectedTimePerTransfer_v; -- 2x slower output acceptance

                -- Expected duration: limited by output acceptance rate
                ExpectedDuration_v := real(NumSamples_c) * Delay_v;

                StartTime_v := now;
                pushData(net, NumSamples_c, 16#3000#); -- push nonblocking, then check blocking
                checkData(net, NumSamples_c, 16#3000#, Delay_v);
                EndTime_v   := now;

                checkTiming(StartTime_v, EndTime_v, ExpectedDuration_v, Tolerance_v);

            elsif run("Throttled") then
                -- Test case 3: Data pushed through at full speed (rate limited)

                -- Expected duration: limited by rate limiter
                ExpectedDuration_v := real(NumSamples_c) * ExpectedTimePerTransfer_v;

                StartTime_v := now;
                pushData(net, NumSamples_c, 16#4000#);
                checkData(net, NumSamples_c, 16#4000#);

                -- Wait until everything done
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));
                EndTime_v := now;

                -- Check burst behavior
                if Period_g > 1 and Period_g > MaxSamples_g then -- For Period_g = 1 or Period_g=MaxSamples_g, there is no rate limiting
                    if Mode_g = "BLOCK" then
                        -- In BLOCK mode, maximum burst size is fixed for non-random-stall case and can
                        -- be anywhere between 1 and 2*MaxSamples_g for random stall case (see documentation for
                        -- reasons).
                        if RandomStall_g then
                            check(MaxBurstSize >= 1 and MaxBurstSize <= 2*MaxSamples_g,
                                "Maximum burst size " & integer'image(MaxBurstSize) & "not within 1...2*MaxSamples_g for BLOCK/RandomStall");
                        else
                            check_equal(MaxBurstSize, MaxSamples_g, "Maximum burst size for BLOKC/Non-random-stall");
                        end if;
                    elsif Mode_g = "SMOOTH" and MaxSamples_g*2 < Period_g then
                        -- In SMOOTH mode, maximum burst size should not exceed 1
                        check_equal(MaxBurstSize, 1, "Maximum burst size for SMOOTH mode");
                    end if;
                end if;

                -- Check Timing
                checkTiming(StartTime_v, EndTime_v, ExpectedDuration_v, Tolerance_v);

            elsif run("RuntimeConfig") then

                -- Execute only if runtime configuration is enabled
                if RuntimeCfg_g then

                    -- Loop through configurations
                    for idx in RtCfgs_c'range loop
                        Cfg_v := RtCfgs_c(idx);

                        -- Skip if config out of range
                        if Cfg_v.MaxSamples > MaxSamples_g or Cfg_v.Period > Period_g then
                            next;
                        end if;

                        -- Reconfigure and reset burst measurement
                        RstBurstmeas   <= true;
                        Cfg_Period     <= toUslv(Cfg_v.Period - 1, Cfg_Period'length);
                        Cfg_MaxSamples <= toUslv(Cfg_v.MaxSamples - 1, Cfg_MaxSamples'length);
                        wait for 5*Clk_Period_c;
                        RstBurstmeas   <= false;

                        -- Prepare test parameters
                        ExpectedTimePerTransfer_v := (real(Cfg_v.Period) / real(Cfg_v.MaxSamples)) * Clk_Period_c;
                        Tolerance_v               := (real(Cfg_v.Period  + 2)) * Clk_Period_c;
                        ExpectedDuration_v        := real(NumSamples_c) * ExpectedTimePerTransfer_v;

                        -- Run test
                        StartTime_v := now;
                        pushData(net, NumSamples_c, 16#5000# + idx * 100);
                        checkData(net, NumSamples_c, 16#5000# + idx * 100);

                        -- Wait until everything done
                        wait_until_idle(net, as_sync(AxisMaster_c));
                        wait_until_idle(net, as_sync(AxisSlave_c));
                        EndTime_v := now;

                        -- Check timing
                        checkTiming(StartTime_v, EndTime_v, ExpectedDuration_v, Tolerance_v);
                    end loop;

                end if;

            end if;

            -- Wait for all verification components to be idle
            wait for 1 us;
            wait_until_idle(net, as_sync(AxisSlave_c));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Maximum Burst Size Detector
    -----------------------------------------------------------------------------------------------
    -- Detect the maximum burst size during a test-case to check if the rate limitation
    -- works as expected.
    p_burst_monitor : process (Clk) is
        variable BurstSize_v  : integer := 0;
        variable FirstBurst_v : boolean := true;
    begin
        if rising_edge(Clk) then
            if Rst = '1' or RstBurstmeas then
                BurstSize_v  := 0;
                MaxBurstSize <= 0;
                FirstBurst_v := true;
            elsif Out_Valid = '1' and Out_Ready = '1' then
                BurstSize_v := BurstSize_v + 1;
                if BurstSize_v > MaxBurstSize then
                    MaxBurstSize <= BurstSize_v;
                end if;
            elsif Out_Valid = '0' or Out_Ready = '0' then
                BurstSize_v := 0;
                -- Ignore first burst (might be affected by transients
                if FirstBurst_v and MaxBurstSize > 0 then
                    MaxBurstSize <= 0;
                    FirstBurst_v := false;
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
            MaxSamples_g    => MaxSamples_g,
            RuntimeCfg_g    => RuntimeCfg_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Data        => In_Data,
            In_Valid       => In_Valid,
            In_Ready       => In_Ready,
            Out_Data       => Out_Data,
            Out_Valid      => Out_Valid,
            Out_Ready      => Out_Ready,
            Cfg_Period     => Cfg_Period,
            Cfg_MaxSamples => Cfg_MaxSamples
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