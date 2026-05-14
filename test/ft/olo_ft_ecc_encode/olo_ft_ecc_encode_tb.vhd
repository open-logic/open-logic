---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_ecc_encode_tb is
    generic (
        runner_cfg : string;
        Width_g    : positive range 5 to 128 := 32;
        Pipeline_g : natural  range 0 to 1   := 0;
        Stalling_g : boolean                 := false
    );
end entity;

architecture sim of olo_ft_ecc_encode_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    constant NoFlip_c : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');

    -- When Stalling_g=true, both VCs introduce random stalls so the codec's UseReady_g=true
    -- shadow-register backpressure path is exercised. boolean'pos(true)=1, boolean'pos(false)=0.
    constant StallProb_c : real    := real(boolean'pos(Stalling_g)) * 0.5;
    constant StallMin_c  : natural := boolean'pos(Stalling_g) * 1;
    constant StallMax_c  : natural := boolean'pos(Stalling_g) * 5;

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length  => Width_g,
        stall_config => new_stall_config(StallProb_c, StallMin_c, StallMax_c)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length  => CodewordWidth_c,
        stall_config => new_stall_config(StallProb_c, StallMin_c, StallMax_c)
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                      := '0';
    signal Rst            : std_logic                                      := '1';
    signal In_Valid       : std_logic                                      := '0';
    signal In_Ready       : std_logic;
    signal In_Data        : std_logic_vector(Width_g - 1 downto 0)         := (others => '0');
    signal ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_Valid   : std_logic                                      := '0';
    signal Out_Valid      : std_logic;
    signal Out_Ready      : std_logic;
    signal Out_Codeword   : std_logic_vector(CodewordWidth_c - 1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- Helpers
    -----------------------------------------------------------------------------------------------
    procedure pushAndCheck (
        signal   net       : inout network_t;
        constant Data_v    : in    std_logic_vector;
        constant Flip_v    : in    std_logic_vector;
        constant Message_c : in    string) is
        variable Expected_v : std_logic_vector(CodewordWidth_c - 1 downto 0);
    begin
        Expected_v := eccEncode(Data_v) xor Flip_v;
        push_axi_stream(net, AxisMaster_c, Data_v);
        check_axi_stream(net, AxisSlave_c, Expected_v, msg => Message_c, blocking => false);
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst            <= '1';
            ErrInj_BitFlip <= (others => '0');
            ErrInj_Valid   <= '0';
            wait for 200 ns;
            wait until rising_edge(Clk);
            Rst            <= '0';
            wait until rising_edge(Clk);

            -- No-flip baseline: clean encode path
            if run("Encode-NoFlip") then
                ErrInj_BitFlip <= NoFlip_c;
                ErrInj_Valid   <= '0';
                pushAndCheck(net, toUslv(0,         Width_g),           NoFlip_c, "data=0");
                pushAndCheck(net, toUslv(16#5A#,    Width_g),           NoFlip_c, "data=5A");
                pushAndCheck(net, onesVector(Width_g),                  NoFlip_c, "data=allOnes");

            -- Single-bit injection at every codeword position via the direct-apply path
            -- (ErrInj_Valid held high alongside the beat)
            elsif run("Encode-SingleFlip-Direct") then
                ErrInj_Valid <= '1';

                for i in 0 to CodewordWidth_c - 1 loop
                    ErrInj_BitFlip <= setBits(i, CodewordWidth_c);
                    pushAndCheck(net, toUslv(16#A5#, Width_g),
                        setBits(i, CodewordWidth_c),
                        "direct flip at " & integer'image(i));
                    wait_until_idle(net, as_sync(AxisMaster_c));
                    wait_until_idle(net, as_sync(AxisSlave_c));
                end loop;

                ErrInj_Valid <= '0';

            -- Double-bit injection sample set (direct-apply path)
            elsif run("Encode-DoubleFlip-Direct") then
                ErrInj_Valid <= '1';

                ErrInj_BitFlip <= setBits((0, 1), CodewordWidth_c);
                pushAndCheck(net, toUslv(16#5A#, Width_g), setBits((0, 1), CodewordWidth_c), "(0,1)");
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                ErrInj_BitFlip <= setBits((0, CodewordWidth_c - 1), CodewordWidth_c);
                pushAndCheck(net, toUslv(16#5A#, Width_g), setBits((0, CodewordWidth_c - 1), CodewordWidth_c), "(0,N-1)");
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                ErrInj_BitFlip <= setBits((1, 2), CodewordWidth_c);
                pushAndCheck(net, toUslv(16#5A#, Width_g), setBits((1, 2), CodewordWidth_c), "(1,2)");
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                ErrInj_BitFlip <= setBits((2, 5), CodewordWidth_c);
                pushAndCheck(net, toUslv(16#5A#, Width_g), setBits((2, 5), CodewordWidth_c), "(2,5)");
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                ErrInj_BitFlip <= setBits((CodewordWidth_c / 2, CodewordWidth_c / 2 + 1), CodewordWidth_c);
                pushAndCheck(net, toUslv(16#5A#, Width_g),
                    setBits((CodewordWidth_c / 2, CodewordWidth_c / 2 + 1), CodewordWidth_c), "(mid,mid+1)");
                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                ErrInj_Valid <= '0';

            -- Back-to-back stress test. With Stalling_g=true, both VCs randomly stall their
            -- handshakes so the codec's UseReady_g=true shadow-register backpressure path
            -- (and any pl_stage register chain) is exercised. With Stalling_g=false the same
            -- test verifies the no-stall fast path produces matching codewords.
            elsif run("Encode-BackToBack") then

                for i in 0 to 31 loop
                    pushAndCheck(net, toUslv(i, Width_g), NoFlip_c,
                        "back-to-back beat " & integer'image(i));
                end loop;

            -- Latched injection: preload the pattern while no beat is being pushed, then
            -- push a beat and verify the latched pattern was applied.
            elsif run("Encode-LatchedInjection") then
                ErrInj_BitFlip <= setBits(3, CodewordWidth_c);
                ErrInj_Valid   <= '1';
                wait until rising_edge(Clk);
                ErrInj_Valid   <= '0';

                -- Idle a few cycles to prove the latch holds
                for i in 0 to 4 loop
                    wait until rising_edge(Clk);
                end loop;

                pushAndCheck(net, toUslv(16#3C#, Width_g), setBits(3, CodewordWidth_c),
                    "latched flip applied to first beat");

                -- Next beat must be clean
                pushAndCheck(net, toUslv(16#3C#, Width_g), NoFlip_c,
                    "latch cleared after first beat");

            end if;

            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));
            wait for 1 us;

        end loop;

        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => Pipeline_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => In_Valid,
            In_Ready       => In_Ready,
            In_Data        => In_Data,
            Out_Valid      => Out_Valid,
            Out_Ready      => Out_Ready,
            Out_Codeword   => Out_Codeword,
            ErrInj_BitFlip => ErrInj_BitFlip,
            ErrInj_Valid   => ErrInj_Valid
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
            TData  => Out_Codeword
        );

end architecture;
