---------------------------------------------------------------------------------------------------
-- Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple I2C-master (multi master capable)
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_i2c_master.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Package for Interface Simplification
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

package olo_intf_i2c_master_pkg is

    constant I2cCmd_Start_c    : std_logic_vector(2 downto 0) := "000";
    constant I2cCmd_Stop_c     : std_logic_vector(2 downto 0) := "001";
    constant I2cCmd_RepStart_c : std_logic_vector(2 downto 0) := "010";
    constant I2cCmd_Send_c     : std_logic_vector(2 downto 0) := "011";
    constant I2cCmd_Receive_c  : std_logic_vector(2 downto 0) := "100";

end package;

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;
    use work.olo_base_pkg_attribute.all;
    use work.olo_intf_i2c_master_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_intf_i2c_master is
    generic (
        ClkFrequency_g      : real;
        I2cFrequency_g      : real    := 100.0e3;
        BusBusyTimeout_g    : real    := 1.0e-3;
        CmdTimeout_g        : real    := 1.0e-3;
        InternalTriState_g  : boolean := true;
        DisableAsserts_g    : boolean := false
    );
    port (
        -- Control Signals
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Command Interface
        Cmd_Ready       : out   std_logic;
        Cmd_Valid       : in    std_logic;
        Cmd_Command     : in    std_logic_vector(2 downto 0);
        Cmd_Data        : in    std_logic_vector(7 downto 0);
        Cmd_Ack         : in    std_logic;
        -- Response Interface
        Resp_Valid      : out   std_logic;
        Resp_Command    : out   std_logic_vector(2 downto 0);
        Resp_Data       : out   std_logic_vector(7 downto 0);
        Resp_Ack        : out   std_logic;
        Resp_ArbLost    : out   std_logic;
        Resp_SeqErr     : out   std_logic;
        -- Status Interface
        Status_BusBusy  : out   std_logic;
        Status_CmdTo    : out   std_logic;
        -- I2c Interface with internal Tri-State
        I2c_Scl         : inout std_logic;
        I2c_Sda         : inout std_logic;
        -- I2c Interface with external Tri-State
        I2c_Scl_i       : in    std_logic := '0';
        I2c_Scl_o       : out   std_logic;
        I2c_Scl_t       : out   std_logic;
        I2c_Sda_i       : in    std_logic := '0';
        I2c_Sda_o       : out   std_logic;
        I2c_Sda_t       : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_intf_i2c_master is

    -- *** Constants ***
    constant BusyTimoutLimit_c    : integer := integer(ClkFrequency_g * BusBusyTimeout_g) - 1;
    constant QuarterPeriodLimit_c : integer := integer(ceil(ClkFrequency_g / I2cFrequency_g / 4.0)) - 1;
    constant CmdTimeoutLimit_c    : integer := integer(ClkFrequency_g * CmdTimeout_g) - 1;

    -- *** Types ***
    type Fsm_t is (
        BusIdle_s, BusBusy_s, MinIdle_s, Start1_s, Start2_s, WaitCmd_s, WaitLowCenter_s,
        Stop1_s, Stop2_s, Stop3_s, RepStart1_s, DataBit1_s, DataBit2_s, DataBit3_s, DataBit4_s, ArbitLost_s
    );

    -- *** Two Process Method ***
    type TwoProcess_r is record
        Status_BusBusy : std_logic;
        Cmd_Ready      : std_logic;
        SclLast        : std_logic;
        SdaLast        : std_logic;
        BusBusyToCnt   : unsigned(log2ceil(BusyTimoutLimit_c + 1) - 1 downto 0);
        TimeoutCmdCnt  : unsigned(log2ceil(CmdTimeoutLimit_c + 1) - 1 downto 0);
        QuartPeriodCnt : unsigned(log2ceil(QuarterPeriodLimit_c + 1) - 1 downto 0);
        QPeriodTick    : std_logic;
        CmdTypeLatch   : std_logic_vector(Cmd_Command'range);
        CmdAckLatch    : std_logic;
        Fsm            : Fsm_t;
        SclOut         : std_logic;
        SdaOut         : std_logic;
        Resp_Valid     : std_logic;
        Resp_Ack       : std_logic;
        Resp_SeqErr    : std_logic;
        Resp_Data      : std_logic_vector(7 downto 0);
        Resp_ArbLost   : std_logic;
        BitCnt         : unsigned(3 downto 0); -- 8 Data + 1 Ack = 9 = 4 bits
        ShReg          : std_logic_vector(8 downto 0);
        CmdTimeout     : std_logic;
        Status_CmdTo   : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- Required to Fix Vivado 2018.2 Synthesis Bug! Is fixed in Vivado 2019.1 according to Xilinx.
    attribute dont_touch of r : signal is DontTouch_SuppressChanges_c;

    -- Tri-state buffer muxing
    signal I2cScl_Input : std_logic;
    signal I2cSda_Input : std_logic;
    signal I2cScl_Sync  : std_logic;
    signal I2cSda_Sync  : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v                     : TwoProcess_r;
        variable SdaRe_v, SdaFe_v      : std_logic;
        variable I2cStart_v, I2cStop_v : std_logic;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Edge Detection ***
        -- SclRe_v   := not r.SclLast and I2cScl_Sync;
        -- SclFe_v   := r.SclLast and not I2cScl_Sync;
        SdaRe_v   := not r.SdaLast and I2cSda_Sync;
        SdaFe_v   := r.SdaLast and not I2cSda_Sync;
        v.SclLast := I2cScl_Sync;
        v.SdaLast := I2cSda_Sync;

        -- *** Start/Stop Detection ***
        I2cStart_v := r.SclLast and I2cScl_Sync and SdaFe_v;
        I2cStop_v  := r.SclLast and I2cScl_Sync and SdaRe_v;

        -- *** Quarter Period Counter ***
        -- The FSM may overwrite the counter in some cases!
        v.QPeriodTick := '0';
        if (r.Fsm = BusIdle_s) or (r.Fsm = BusBusy_s) then
            v.QuartPeriodCnt := (others => '0');
        elsif r.QuartPeriodCnt = QuarterPeriodLimit_c then
            v.QuartPeriodCnt := (others => '0');
            v.QPeriodTick    := '1';
        else
            v.QuartPeriodCnt := r.QuartPeriodCnt + 1;
        end if;

        -- *** Command Timeout Detection ***
        if r.Fsm = WaitCmd_s then
            -- Timeout
            if r.TimeoutCmdCnt = CmdTimeoutLimit_c then
                v.CmdTimeout := '1';
            -- Count
            else
                v.TimeoutCmdCnt := r.TimeoutCmdCnt + 1;
            end if;
        -- In all states except waiting for command, reset the timer
        else
            v.TimeoutCmdCnt := (others => '0');
        end if;

        -- *** Latch Command ***
        if (r.Cmd_Ready = '1') and (Cmd_Valid = '1') then
            v.CmdTypeLatch := Cmd_Command;
            v.CmdAckLatch  := Cmd_Ack;
        end if;

        -- *** Default Values ***
        v.Resp_Valid   := '0';
        v.Resp_Ack     := not r.ShReg(0);
        v.Resp_Data    := r.ShReg(8 downto 1);
        v.Resp_SeqErr  := '0';
        v.Resp_ArbLost := '0';
        v.Status_CmdTo := '0';
        v.Cmd_Ready    := '0';

        -- *** FSM ***
        case r.Fsm is

            -- Bus Idle
            when BusIdle_s =>
                -- Default Outputs
                v.Cmd_Ready    := '1';
                v.BusBusyToCnt := (others => '0');
                v.SclOut       := '1';
                v.SdaOut       := '1';
                v.CmdTimeout   := '0';

                -- Detect Bus Busy by Start Command
                if (r.Cmd_Ready = '1') and (Cmd_Valid = '1') then
                    -- Everyting else than START commands is ignored and an error is printed in this case
                    assert (Cmd_Command = I2cCmd_Start_c) or DisableAsserts_g
                        report "###ERROR###: olo_intf_i2c_master: In idle state, only I2cCmd_Start_c commands are allowed!"
                        severity error;
                    v.CmdTypeLatch := Cmd_Command;
                    if Cmd_Command = I2cCmd_Start_c then
                        v.Fsm       := Start1_s;
                        v.Cmd_Ready := '0';
                    else
                        v.Resp_Valid  := '1';
                        v.Resp_SeqErr := '1';
                    end if;
                -- Detect Busy from other master
                elsif (I2cScl_Sync = '0') or (I2cStart_v = '1') then
                    v.Fsm       := BusBusy_s;
                    v.Cmd_Ready := '0';
                end if;

            -- Bus Busy by other master
            when BusBusy_s =>
                -- Bus released
                if I2cStop_v = '1' then
                    v.Fsm := MinIdle_s;
                end if;
                -- Timeout Handling
                if I2cScl_Sync = '0' then
                    v.BusBusyToCnt := (others => '0');
                elsif r.BusBusyToCnt = BusyTimoutLimit_c then
                    v.Fsm := BusIdle_s;
                else
                    v.BusBusyToCnt := r.BusBusyToCnt + 1;
                end if;

                v.SclOut := '1';
                v.SdaOut := '1';

            -- Ensure that SDA stays low for at least half a clock period after the bus was released
            when MinIdle_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm := BusIdle_s;
                end if;

                v.SclOut := '1';
                v.SdaOut := '1';

            -- Start Condition
            --------------------------------------------------------------------------------
            -- State    BusBusy_s   Start1_s   Start2_s   WaitCmd_s
            -- __________________________________
            -- Scl ...                                  |___________ ...
            -- _______________________
            -- SDA ...                       |______________________ ...
            when Start1_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm := Start2_s;
                end if;

                -- Handle Clock Stretching in case of a repeated start (slave keeps SCL low)
                if I2cScl_Sync = '0' and r.CmdTypeLatch = I2cCmd_RepStart_c then
                    v.QuartPeriodCnt := (others => '0');
                end if;

                -- Handle Arbitration (other master transmits start condition first)
                if I2cSda_Sync = '0' then
                    v.Fsm := ArbitLost_s;
                end if;

                v.SclOut := '1';
                v.SdaOut := '1';

            when Start2_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm        := WaitCmd_s;
                    v.Resp_Valid := '1';
                end if;
                v.SclOut := '1';
                v.SdaOut := '0';

            -- Wait for user command (in first half of SCL low phase)

            when WaitCmd_s =>
                -- Default Outputs
                v.Cmd_Ready := '1';
                v.SclOut    := '0';

                -- All commands except START are allowed, START commands are ignored
                if (r.Cmd_Ready = '1') and (Cmd_Valid = '1') then
                    assert (Cmd_Command = I2cCmd_Stop_c) or (Cmd_Command = I2cCmd_RepStart_c) or
                           (Cmd_Command = I2cCmd_Send_c) or (Cmd_Command = I2cCmd_Receive_c) or DisableAsserts_g
                        report "###ERROR###: olo_intf_i2c_master: In WaitCmd_s state, I2cCmd_Start_c commands are not allowed!"
                        severity error;
                    if (Cmd_Command = I2cCmd_Stop_c) or (Cmd_Command = I2cCmd_RepStart_c) or
                       (Cmd_Command = I2cCmd_Send_c) or (Cmd_Command = I2cCmd_Receive_c) then
                        v.Fsm       := WaitLowCenter_s;
                        v.Cmd_Ready := '0';
                    else
                        v.Resp_Valid  := '1';
                        v.Resp_SeqErr := '1';
                    end if;
                    -- Latch data (used for SEND)
                    v.ShReg := Cmd_Data & '0';
                -- Command timeout - In this case send a STOP to free the bus
                elsif r.CmdTimeout = '1' then
                    v.Fsm          := WaitLowCenter_s;
                    v.Cmd_Ready    := '0';
                    v.Status_CmdTo := '1';
                end if;

            -- Wait for center of SCL low phase (after user command arrived)
            when WaitLowCenter_s =>
                -- State Handling
                v.SclOut := '0';
                v.BitCnt := (others => '0');

                -- Switch to commands
                if r.QPeriodTick = '1' then
                    -- In timeout case, send a STOP to free the bus
                    if r.CmdTimeout = '1' then
                        v.Fsm := Stop1_s;
                    -- Else, go to requested command
                    else

                        case r.CmdTypeLatch is
                            when I2cCmd_Stop_c => v.Fsm := Stop1_s;
                            when I2cCmd_RepStart_c => v.Fsm := RepStart1_s;
                            when I2cCmd_Send_c => v.Fsm := DataBit1_s;
                            when I2cCmd_Receive_c => v.Fsm := DataBit1_s;
                            -- coverage off
                            when others => null; -- unreacable code
                            -- coverage on
                        end case;

                    end if;
                end if;

            -- Repeated Start Condition
            --------------------------------------------------------------------------------
            -- State       RepStart1_s   Start1_s   Start2_s   WaitCmd_s
            -- _____________________
            -- Scl ..._________________|                     |___________ ...
            -- __________________________
            -- SDA ...XXX                          |_____________________ ...
            -- States after RepStart1_s are shared with normal start condition

            when RepStart1_s =>
                if r.QPeriodTick = '1' then
                    -- The rest of the sequence is same as for START
                    v.Fsm := Start1_s;

                    -- Handle Arbitration other master prvents repeating start by transmitting 0
                    if I2cSda_Sync = '0' then
                        v.Fsm := ArbitLost_s;
                    end if;
                end if;
                v.SclOut := '0';
                v.SdaOut := '1';

            -- Data Bit
            --------------------------------------------------------------------------------
            -- State  DataBit1_s   DataBit2_s   DataBit3_s   WaitCmd_s / DataBit4_s
            -- _________________________
            -- Scl ...___________|                         |___________ ...
            -- -- SDA ...XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
            -- The DataBit1_s is the second half of the SCL low period. So the
            -- SDA Line is set at the beginning of DataBit1_s. After the SCL high period
            -- of the last bit, the state is changed to WaitCmd_s. Otherwise the first half of the SCL low
            -- period is executed (DataBit4_s) before the next bit starts (DataBit1_s)

            when DataBit1_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm := DataBit2_s;
                end if;
                v.SclOut := '0';

                -- Send Operation
                if r.CmdTypeLatch = I2cCmd_Send_c then
                    -- For Ack, receive data
                    if r.BitCnt = 8 then
                        v.SdaOut := '1';
                    -- .. else send data
                    else
                        v.SdaOut := r.ShReg(8);
                    end if;
                -- Receive Operatiom
                else
                    -- Ack Handling
                    if r.BitCnt = 8 then
                        if r.CmdAckLatch = '1' then
                            v.SdaOut := '0';
                        else
                            v.SdaOut := '1';
                        end if;
                    -- .. else tri-state for receiving
                    else
                        v.SdaOut := '1';
                    end if;
                end if;

            when DataBit2_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm := DataBit3_s;
                    -- Shift register in the middle of the CLK pulse
                    v.ShReg := r.ShReg(7 downto 0) & I2cSda_Sync;
                end if;
                v.SclOut := '1';

                -- Handle Clock Stretching (slave keeps SCL low)
                if I2cScl_Sync = '0' then
                    v.QuartPeriodCnt := (others => '0');
                end if;

                -- Handle Arbitration for Sending (only databits, not ack)
                if (r.CmdTypeLatch = I2cCmd_Send_c) and (r.BitCnt /= 8) then
                    if I2cSda_Sync /= r.SdaOut then
                        v.Fsm := ArbitLost_s;
                    end if;
                -- Receiving does not need arbitration since slave addresses are unique
                end if;

            when DataBit3_s =>
                if r.QPeriodTick = '1' then
                    -- Command Done after 9 bits (8 Data + 1 Ack)
                    if r.BitCnt = 8 then
                        v.Fsm        := WaitCmd_s;
                        v.Resp_Valid := '1';
                    -- Else goto next bit
                    else
                        v.Fsm := DataBit4_s;
                    end if;
                end if;
                v.SclOut := '1';

                -- Handle Arbitration for Sending (only databits, not ack)
                if (r.CmdTypeLatch = I2cCmd_Send_c) and (r.BitCnt /= 8) then
                    if I2cSda_Sync /= r.SdaOut then
                        v.Fsm := ArbitLost_s;
                    end if;
                -- Receiving does not need arbitration since slave addresses are unique
                end if;

            when DataBit4_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm    := DataBit1_s;
                    v.BitCnt := r.BitCnt + 1;
                end if;
                v.SclOut := '0';

            -- Stop Condition
            --------------------------------------------------------------------------------
            -- State   WaitCmd_s   Stop1_s   Stop2_s   Stop3_s   BusIdle_s
            -- _____________________
            -- Scl ..._____________________|                     |__________ ...
            -- _____________________
            -- SDA ...XXXXXXXXXXXX____________________|                      ...

            when Stop1_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm := Stop2_s;
                end if;
                v.SclOut := '0';
                v.SdaOut := '0';

            when Stop2_s =>
                if r.QPeriodTick = '1' then
                    v.Fsm := Stop3_s;
                end if;
                v.SclOut := '1';
                v.SdaOut := '0';

                -- Handle Clock Stretching (slave keeps SCL low)
                if I2cScl_Sync = '0' then
                    v.QuartPeriodCnt := (others => '0');
                end if;

            when Stop3_s =>
                if r.QPeriodTick = '1' then
                    -- Handle Arbitration
                    if I2cSda_Sync = '0' then
                        v.Fsm := ArbitLost_s;
                    -- Else the STOP was successful
                    else
                        v.Fsm := BusIdle_s;
                        -- Send response only if the stop was not generated by a timeout
                        if r.CmdTimeout = '0' then
                            v.Resp_Valid := '1';
                        end if;
                    end if;
                end if;
                v.SclOut := '1';
                v.SdaOut := '1';

            -- Send Response in case the arbitration was lost
            when ArbitLost_s =>
                v.Fsm          := BusBusy_s;
                v.Resp_Valid   := '1';
                v.Resp_Ack     := '0';
                v.Resp_ArbLost := '1';
                v.SclOut       := '1';
                v.SdaOut       := '1';

            -- coverage off
            when others => null; -- unreacable code
            -- coverage on
        end case;

        -- *** Bus Busy ***
        if r.Fsm = BusIdle_s then
            v.Status_BusBusy := '0';
        else
            v.Status_BusBusy := '1';
        end if;

        -- *** assign signal ***
        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Status_BusBusy <= r.Status_BusBusy;
    Cmd_Ready      <= r.Cmd_Ready;
    Resp_Valid     <= r.Resp_Valid;
    Resp_Command   <= r.CmdTypeLatch;
    Resp_ArbLost   <= r.Resp_ArbLost;
    Resp_Ack       <= r.Resp_Ack;
    Resp_Data      <= r.Resp_Data;
    Resp_SeqErr    <= r.Resp_SeqErr;
    Status_CmdTo   <= r.Status_CmdTo;

    -- Internal Tri-State buffers
    g_int_tristate : if InternalTriState_g generate
        I2c_Scl   <= 'Z' when r.SclOut = '1' else '0';
        I2c_Sda   <= 'Z' when r.SdaOut = '1' else '0';
        I2c_Scl_o <= '0';
        I2c_Sda_o <= '0';
        I2c_Scl_t <= '1';
        I2c_Sda_t <= '1';
    end generate;

    -- External Tri-State buffers
    g_ext_tristatte : if not InternalTriState_g generate
        I2c_Scl_o <= r.SclOut;
        I2c_Sda_o <= r.SdaOut;
        I2c_Scl_t <= r.SclOut;
        I2c_Sda_t <= r.SdaOut;
        I2c_Scl   <= '0';
        I2c_Sda   <= '0';
    end generate;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.Status_BusBusy <= '0';
                r.Cmd_Ready      <= '0';
                r.SclLast        <= '1';
                r.SdaLast        <= '1';
                r.BusBusyToCnt   <= (others => '0');
                r.Fsm            <= BusIdle_s;
                r.SclOut         <= '1';
                r.SdaOut         <= '1';
                r.Resp_Valid     <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------
    I2cScl_Input <= to01X(I2c_Scl) when InternalTriState_g else I2c_Scl_i;
    I2cSda_Input <= to01X(I2c_Sda) when InternalTriState_g else I2c_Sda_i;

    i_sync : entity work.olo_intf_sync
        generic map (
            Width_g     => 2
        )
        port map (
            Clk             => Clk,
            DataAsync(0)    => I2cScl_Input,
            DataAsync(1)    => I2cSda_Input,
            DataSync(0)     => I2cScl_Sync,
            DataSync(1)     => I2cSda_Sync
        );

end architecture;
