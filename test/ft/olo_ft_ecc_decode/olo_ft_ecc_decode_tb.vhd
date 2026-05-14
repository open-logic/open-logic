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
entity olo_ft_ecc_decode_tb is
    generic (
        runner_cfg : string;
        Width_g    : positive range 5 to 128 := 32;
        Pipeline_g : natural  range 0 to 2   := 0
    );
end entity;

architecture sim of olo_ft_ecc_decode_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    constant NoFlip_c : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    --   TUser carries {Sec, Ded} on the output stream.
    -----------------------------------------------------------------------------------------------
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
        data_length  => CodewordWidth_c,
        stall_config => new_stall_config(0.0, 0, 0)
    );
    constant AxisSlave_c  : axi_stream_slave_t  := new_axi_stream_slave (
        data_length  => Width_g,
        user_length  => 2,
        stall_config => new_stall_config(0.0, 0, 0)
    );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk            : std_logic                                      := '0';
    signal Rst            : std_logic                                      := '1';
    signal In_Valid       : std_logic                                      := '0';
    signal In_Ready       : std_logic;
    signal In_Codeword    : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_BitFlip : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal ErrInj_Valid   : std_logic                                      := '0';
    signal Out_Valid      : std_logic;
    signal Out_Ready      : std_logic;
    signal Out_Data       : std_logic_vector(Width_g - 1 downto 0);
    signal Out_EccSec     : std_logic;
    signal Out_EccDed     : std_logic;
    signal Out_TUser      : std_logic_vector(1 downto 0);

    -----------------------------------------------------------------------------------------------
    -- Helpers
    --   ExtFlip_v: applied to the codeword by the TB before pushing (simulates a corruption on
    --              the channel between encoder and decoder, e.g. an upset in storage).
    --   IntFlip_v: applied INSIDE the DUT via ErrInj_BitFlip + ErrInj_Valid (simulates a fault
    --              injected by the user logic).
    --   ExpSec / ExpDed: expected flags (sanity-asserted; data is checked against the value the
    --              decoder is mathematically required to produce, so the test still passes on DED
    --              even though the data is "wrong" by SECDED definition).
    -----------------------------------------------------------------------------------------------
    procedure pushExpect (
        signal   net       : inout network_t;
        constant Data_v    : in    std_logic_vector;
        constant ExtFlip_v : in    std_logic_vector;
        constant IntFlip_v : in    std_logic_vector;
        constant ExpSec    : in    std_logic;
        constant ExpDed    : in    std_logic;
        constant Message_c : in    string) is
        variable Codeword_v    : std_logic_vector(CodewordWidth_c - 1 downto 0);
        variable EffCodeword_v : std_logic_vector(CodewordWidth_c - 1 downto 0);
        variable SynPar_v      : std_logic_vector(eccParityBits(Width_g) downto 0);
        variable ExpData_v     : std_logic_vector(Width_g - 1 downto 0);
    begin
        Codeword_v    := eccEncode(Data_v) xor ExtFlip_v;
        EffCodeword_v := Codeword_v xor IntFlip_v;
        SynPar_v      := eccSyndromeAndParity(EffCodeword_v, Width_g);
        ExpData_v     := eccCorrectData(EffCodeword_v, SynPar_v, Width_g);

        push_axi_stream(net, AxisMaster_c, Codeword_v);
        check_axi_stream(net, AxisSlave_c, ExpData_v, tuser => ExpSec & ExpDed,
            msg                                             => Message_c, blocking => false);
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

            wait until rising_edge(Clk);
            Rst            <= '1';
            ErrInj_BitFlip <= (others => '0');
            ErrInj_Valid   <= '0';
            wait for 200 ns;
            wait until rising_edge(Clk);
            Rst            <= '0';
            wait until rising_edge(Clk);

            if run("Decode-NoError") then
                pushExpect(net, toUslv(0,         Width_g), NoFlip_c, NoFlip_c, '0', '0', "data=0");
                pushExpect(net, toUslv(16#A5#,    Width_g), NoFlip_c, NoFlip_c, '0', '0', "data=A5");
                pushExpect(net, onesVector(Width_g),        NoFlip_c, NoFlip_c, '0', '0', "data=allOnes");

            -- Sweep single-bit flips across every codeword position; each must be SEC-correctable.
            elsif run("Decode-SecAllBits") then

                for i in 0 to CodewordWidth_c - 1 loop
                    pushExpect(net, toUslv(16#A5#, Width_g),
                        setBits(i, CodewordWidth_c), NoFlip_c,
                        '1', '0',
                        "single flip at " & integer'image(i));
                end loop;

            -- Representative double-bit flip set; each must be DED-detectable.
            elsif run("Decode-DedSampledPairs") then
                pushExpect(net, toUslv(16#5A#, Width_g), setBits((0, 1),                CodewordWidth_c), NoFlip_c, '0', '1', "(0,1)");
                pushExpect(net, toUslv(16#5A#, Width_g), setBits((0, CodewordWidth_c-1), CodewordWidth_c), NoFlip_c, '0', '1', "(0,N-1)");
                pushExpect(net, toUslv(16#5A#, Width_g), setBits((1, 2),                CodewordWidth_c), NoFlip_c, '0', '1', "(1,2)");
                pushExpect(net, toUslv(16#5A#, Width_g), setBits((2, 5),                CodewordWidth_c), NoFlip_c, '0', '1', "(2,5)");
                pushExpect(net, toUslv(16#5A#, Width_g),
                    setBits((CodewordWidth_c / 2, CodewordWidth_c / 2 + 1), CodewordWidth_c), NoFlip_c,
                    '0', '1', "(mid,mid+1)");

            -- Direct-apply path: hold ErrInj_Valid='1' alongside each beat. The pattern XORs
            -- into the codeword combinationally and produces a SEC condition.
            elsif run("Decode-DirectInjection-Sec") then
                ErrInj_Valid <= '1';

                for i in 0 to CodewordWidth_c - 1 loop
                    ErrInj_BitFlip <= setBits(i, CodewordWidth_c);
                    pushExpect(net, toUslv(16#3C#, Width_g),
                        NoFlip_c, setBits(i, CodewordWidth_c),
                        '1', '0',
                        "direct flip at " & integer'image(i));
                    wait_until_idle(net, as_sync(AxisMaster_c));
                    wait_until_idle(net, as_sync(AxisSlave_c));
                end loop;

                ErrInj_Valid   <= '0';
                ErrInj_BitFlip <= (others => '0');

            -- Latched injection: preload an injection pattern, idle a few cycles, then push a
            -- clean codeword and verify the latch is consumed exactly once.
            elsif run("Decode-LatchedInjection") then
                ErrInj_BitFlip <= setBits(2, CodewordWidth_c);
                ErrInj_Valid   <= '1';
                wait until rising_edge(Clk);
                ErrInj_Valid   <= '0';

                for i in 0 to 4 loop
                    wait until rising_edge(Clk);
                end loop;

                pushExpect(net, toUslv(16#5A#, Width_g),
                    NoFlip_c, setBits(2, CodewordWidth_c),
                    '1', '0',
                    "latched flip applied to first beat");

                wait_until_idle(net, as_sync(AxisMaster_c));
                wait_until_idle(net, as_sync(AxisSlave_c));

                pushExpect(net, toUslv(16#5A#, Width_g),
                    NoFlip_c, NoFlip_c,
                    '0', '0',
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

    Out_TUser <= Out_EccSec & Out_EccDed;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_ft_ecc_decode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => Pipeline_g
        )
        port map (
            Clk            => Clk,
            Rst            => Rst,
            In_Valid       => In_Valid,
            In_Ready       => In_Ready,
            In_Codeword    => In_Codeword,
            Out_Valid      => Out_Valid,
            Out_Ready      => Out_Ready,
            Out_Data       => Out_Data,
            Out_EccSec     => Out_EccSec,
            Out_EccDed     => Out_EccDed,
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
            TData  => In_Codeword
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TValid => Out_Valid,
            TReady => Out_Ready,
            TData  => Out_Data,
            TUser  => Out_TUser
        );

end architecture;
