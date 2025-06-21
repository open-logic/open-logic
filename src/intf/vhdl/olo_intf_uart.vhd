---------------------------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler, Franz Herzog
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple UART.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_uart.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

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

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_intf_uart is
    generic (
        ClkFreq_g       : real;
        BaudRate_g      : real                  := 115.2e3;
        DataBits_g      : positive range 7 to 9 := 8;
        StopBits_g      : string                := "1";
        Parity_g        : string                := "none"
    );
    port (
        -- Control Signals
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Tx Data
        Tx_Valid        : in    std_logic                                 := '0';
        Tx_Ready        : out   std_logic;
        Tx_Data         : in    std_logic_vector(DataBits_g - 1 downto 0) := (others => '0');
        -- Rx Data
        Rx_Valid        : out   std_logic;
        Rx_Data         : out   std_logic_vector(DataBits_g - 1 downto 0);
        Rx_ParityError  : out   std_logic;
        -- UART Interface
        Uart_Tx         : out   std_logic;
        Uart_Rx         : in    std_logic                                 := '1'
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_intf_uart is

    -- *** Types ***
    type StateTx_t is (Reset_s, Idle_s, Data_s, Stop_s);
    type StateRx_t is (Idle_s, Start_s, Data_s, Parity_s, Stop_s);

    -- *** Constants ***
    function parityBit (Data : std_logic_vector) return std_logic is
        variable Parity_v : std_logic := '0';
    begin
        if Parity_g = "none" then
            return '0';
        end if;

        -- Calculate Parity
        for i in Data'range loop
            Parity_v := Parity_v xor Data(i);
        end loop;

        if Parity_g = "even" then
            return Parity_v;
        else
            return not Parity_v;
        end if;
    end function;

    function stopStrobeCount return natural is
    begin
        if StopBits_g = "1" then
            return 2;
        elsif StopBits_g = "1.5" then
            return 3;
        else
            return 4;
        end if;
    end function;

    function transmitBits return natural is
        variable Bits_v : natural := DataBits_g;
    begin
        -- Start Bit
        Bits_v := Bits_v + 1;
        -- Parity Bit
        if Parity_g /= "none" then
            Bits_v := Bits_v + 1;
        end if;
        return Bits_v;
    end function;

    -- *** Two Process Method ***
    type TwoProcess_r is record
        -- TX
        StateTx        : StateTx_t;
        TxCount        : natural range 0 to transmitBits*2 - 1;
        Tx_Ready       : std_logic;
        TxSync         : std_logic;
        TxShiftReg     : std_logic_vector(DataBits_g+1 downto 0);
        Uart_Tx        : std_logic;
        -- RX
        StateRx        : StateRx_t;
        RxCount        : natural range 0 to DataBits_g*2 - 1;
        RxSync         : std_logic;
        RxShiftReg     : std_logic_vector(DataBits_g-1 downto 0);
        Rx_ParityError : std_logic;
        Rx_Valid       : std_logic;
    end record;

    signal r, r_next : TwoProcess_r;

    -- *** Instantiation Signals ***
    signal TxStrobe  : std_logic;
    signal RxStrobe  : std_logic;
    signal UartRxInt : std_logic;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert BaudRate_g > 0.0
        report "olo_intf_uart - BaudRate_g must be greater than 0"
        severity error;

    assert StopBits_g = "1" or StopBits_g = "1.5" or StopBits_g = "2"
        report "olo_intf_uart - StopBits_g must be 1, 1.5 or 2"
        severity error;

    assert Parity_g = "none" or Parity_g = "even" or Parity_g = "odd"
        report "olo_intf_uart - Parity_g must be none, even or odd"
        severity error;

    assert BaudRate_g <= ClkFreq_g / 10.0
        report "olo_intf_uart - BaudRate_g must be <= ClkFreq_g / 10.0"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** TX FSM ***
        -- Default Values
        v.TxSync  := '0';
        v.Uart_Tx := '1';

        -- FSM
        case r.StateTx is
            when Reset_s =>
                v.Tx_Ready := '1';
                v.StateTx  := Idle_s;

            when Idle_s =>
                -- Only switch to new state if data is latched and strobe is found
                if r.Tx_Ready = '0' and TxStrobe = '1' then
                    v.StateTx := Data_s;
                    v.TxCount := 0;
                -- Latch Data and de-assert ready on Tx_Valid
                elsif Tx_Valid = '1' and r.Tx_Ready = '1' then
                    v.Tx_Ready   := '0';
                    v.TxSync     := '1';
                    v.TxShiftReg := parityBit(Tx_Data) & Tx_Data & '0';
                end if;

            when Data_s =>
                v.Uart_Tx := r.TxShiftReg(0);
                if TxStrobe = '1' then
                    -- Switch to new state after last bit is transferred
                    if r.TxCount = transmitBits*2 - 1 then
                        v.TxCount := 0;
                        v.StateTx := Stop_s;
                    else
                        -- On every second strobe of a bit shift the register
                        if r.TxCount mod 2 = 1 then
                            v.TxShiftReg := '0' & r.TxShiftReg(r.TxShiftReg'high downto 1);
                        end if;
                        v.TxCount := r.TxCount + 1;
                    end if;
                end if;

            when Stop_s =>
                v.Uart_Tx := '1';
                if TxStrobe = '1' then
                    -- Switch to idle after stop bit
                    if r.TxCount = stopStrobeCount-1 then
                        v.StateTx  := Idle_s;
                        v.Tx_Ready := '1';
                    else
                        v.TxCount := r.TxCount + 1;
                    end if;
                end if;

            -- coverage off
            when others =>
                null; -- unreachable code
            -- coverage on

        end case;

        -- *** RX FSM ***
        -- Default Values
        v.RxSync   := '0';
        v.Rx_Valid := '0';

        -- FSM
        case r.StateRx is
            when Idle_s =>
                v.Rx_ParityError := '0';
                -- Latch Data on Start Bit
                if UartRxInt = '0' then
                    v.RxSync  := '1';
                    v.StateRx := Start_s;
                    v.RxCount := 0;
                end if;

            when Start_s =>
                if RxStrobe = '1' then
                    -- Go to data reception after start bit
                    if r.RxCount = 2 then
                        v.StateRx := Data_s;
                        v.RxCount := 0;
                    -- If line is high in the center of the start-bit, assume the low-pulse to be a glitch
                    -- and regurn ot idle
                    else
                        if UartRxInt = '1' then
                            v.StateRx := Idle_s;
                        end if;
                        v.RxCount := r.RxCount + 1;
                    end if;
                end if;

            when Data_s =>
                if RxStrobe = '1' then
                    -- Shift register on center-bit-strobe
                    if r.RxCount mod 2 = 0 then
                        v.RxShiftReg := UartRxInt & r.RxShiftReg(DataBits_g-1 downto 1);
                    end if;
                    -- Switch to next state after last bit
                    if r.RxCount = DataBits_g*2 - 1 then
                        if Parity_g = "none" then
                            v.StateRx := Stop_s;
                        else
                            v.StateRx := Parity_s;
                        end if;
                        v.RxCount := 0;
                    else
                        v.RxCount := r.RxCount + 1;
                    end if;
                end if;

            when Parity_s =>
                if RxStrobe = '1' then
                    -- Go to stop bit after parity bit
                    if r.RxCount = 1 then
                        v.StateRx := Stop_s;
                    else
                        v.RxCount := r.RxCount + 1;
                        -- Check parity in the center of the parity bit
                        if UartRxInt /= parityBit(r.RxShiftReg) then
                            v.Rx_ParityError := '1';
                        end if;
                    end if;
                end if;

            when Stop_s =>
                -- The stop bit is not checked. The state is left after half a bit-time
                if RxStrobe = '1' then
                    v.StateRx  := Idle_s;
                    v.Rx_Valid := '1';
                end if;

            -- coverage off
            when others =>
                null; -- unreachable code
            -- coverage on

        end case;

        -- *** assign signal ***
        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Tx_Ready       <= r.Tx_Ready;
    Uart_Tx        <= r.Uart_Tx;
    Rx_ParityError <= r.Rx_ParityError;
    Rx_Data        <= r.RxShiftReg;
    Rx_Valid       <= r.Rx_Valid;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                -- Tx
                r.StateTx  <= Reset_s;
                r.Tx_Ready <= '0';
                -- Rx
                r.StateRx <= Idle_s;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Component Instantiations
    -----------------------------------------------------------------------------------------------
    i_strb_tx : entity work.olo_base_strobe_gen
        generic map (
            FreqClkHz_g      => ClkFreq_g,
            FractionalMode_g => true,
            FreqStrobeHz_g   => BaudRate_g*2.0 -- 2x baud rate
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Sync     => r.TxSync,
            Out_Valid   => TxStrobe
        );

    i_strb_rx : entity work.olo_base_strobe_gen
        generic map (
            FreqClkHz_g      => ClkFreq_g,
            FractionalMode_g => true,
            FreqStrobeHz_g   => BaudRate_g*2.0 -- 2x baud rate
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Sync     => r.RxSync,
            Out_Valid   => RxStrobe
        );

    i_sync : entity work.olo_intf_sync
        port map (
            Clk             => Clk,
            Rst             => Rst,
            DataAsync(0)    => Uart_Rx,
            DataSync(0)     => UartRxInt
        );

end architecture;

