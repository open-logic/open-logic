---------------------------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements an AXI-Lite Slave Interface, which can be used to
-- access registers and memory. On the user-side it provides a simple
-- read/write/address/data interface.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/axi/olo_axi_lite_slave.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_axi_pkg_protocol.all;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_axi_lite_slave is
    generic (
        AxiAddrWidth_g      : positive := 8;
        AxiDataWidth_g      : positive := 32;
        ReadTimeoutClks_g   : positive := 100
    );
    port (
        -- Control Sgignals
        Clk               : in    std_logic;
        Rst               : in    std_logic;
        -- AXI-Lite Interface
        -- AR channel
        S_AxiLite_ArAddr  : in    std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        S_AxiLite_ArValid : in    std_logic;
        S_AxiLite_ArReady : out   std_logic;
        -- AW channel
        S_AxiLite_AwAddr  : in    std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        S_AxiLite_AwValid : in    std_logic;
        S_AxiLite_AwReady : out   std_logic;
        -- W channel
        S_AxiLite_WData   : in    std_logic_vector(AxiDataWidth_g - 1 downto 0);
        S_AxiLite_WStrb   : in    std_logic_vector((AxiDataWidth_g/8) - 1 downto 0);
        S_AxiLite_WValid  : in    std_logic;
        S_AxiLite_WReady  : out   std_logic;
        -- B channel
        S_AxiLite_BResp   : out   std_logic_vector(1 downto 0);
        S_AxiLite_BValid  : out   std_logic;
        S_AxiLite_BReady  : in    std_logic;
        -- R channel
        S_AxiLite_RData   : out   std_logic_vector(AxiDataWidth_g - 1 downto 0);
        S_AxiLite_RResp   : out   std_logic_vector(1 downto 0);
        S_AxiLite_RValid  : out   std_logic;
        S_AxiLite_RReady  : in    std_logic;
        -- Register Interface
        Rb_Addr           : out   std_logic_vector(AxiAddrWidth_g - 1 downto 0);
        Rb_Wr             : out   std_logic;
        Rb_ByteEna        : out   std_logic_vector((AxiDataWidth_g/8) - 1 downto 0);
        Rb_WrData         : out   std_logic_vector(AxiDataWidth_g - 1 downto 0);
        Rb_Rd             : out   std_logic;
        Rb_RdData         : in    std_logic_vector(AxiDataWidth_g - 1 downto 0);
        Rb_RdValid        : in    std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture rtl of olo_axi_lite_slave is

    -- FSM Type
    type Fsm_t is (Idle, WrCmd, WrData, WrResp, RdCmd, RdData, RdResp);

    -- TwoProcess Record
    type TwoProcess_r is record
        State   : Fsm_t;
        ArReady : std_logic;
        AwReady : std_logic;
        WReady  : std_logic;
        BValid  : std_logic;
        RValid  : std_logic;
        RData   : std_logic_vector(Rb_RdData'range);
        Addr    : std_logic_vector(Rb_Addr'range);
        ByteEna : std_logic_vector(Rb_ByteEna'range);
        WrData  : std_logic_vector(Rb_WrData'range);
        Wr      : std_logic;
        Rd      : std_logic;
        RResp   : Resp_t;
        ToCnt   : natural range 0 to ReadTimeoutClks_g-1;
    end record;

    signal r, r_next : TwoProcess_r;

    constant UnusedBits_c : natural := log2(AxiDataWidth_g/8);

begin

    -- *** Assertions ***
    assert AxiDataWidth_g mod 8 = 0
        report "###ERROR###: olo_axi_lite_slave AxiDataWidth_g must be a multiple of 8"
        severity failure;
    assert isPower2(AxiDataWidth_g/8)
        report "###ERROR###: olo_axi_lite_slave AxiDataWidth_g must be 2^X bytes"
        severity failure;

    -- *** Combinatorial Process ***
    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- Keep variables stable
        v := r;

        -- Default values
        v.ArReady := '0';
        v.AwReady := '0';
        v.Wr      := '0';
        v.Rd      := '0';

        -- FSM
        case r.State is
            -- Idle
            when Idle =>
                -- Idle
                if S_AxiLite_ArValid = '1' then
                    v.State   := RdCmd;
                    v.ArReady := '1';
                elsif S_AxiLite_AwValid = '1' then
                    v.State   := WrCmd;
                    v.AwReady := '1';
                end if;

            -- Write
            when WrCmd =>
                -- Latch write command
                v.Addr := S_AxiLite_AwAddr(S_AxiLite_AwAddr'high downto UnusedBits_c) & zerosVector(UnusedBits_c);
                -- Get ready for write data
                v.WReady := '1';
                v.State  := WrData;

            when WrData =>
                -- Receive write data
                if S_AxiLite_WValid = '1' then
                    v.State   := WrResp;
                    v.WReady  := '0';
                    v.ByteEna := S_AxiLite_WStrb;
                    v.WrData  := S_AxiLite_WData;
                    v.Wr      := '1';
                    v.BValid  := '1';
                end if;

            when WrResp =>
                -- Wait for response transferred
                if S_AxiLite_BReady = '1' then
                    v.State  := Idle;
                    v.BValid := '0';
                end if;

            -- Read
            when RdCmd =>
                -- Forward read command
                v.Addr  := S_AxiLite_ArAddr;
                v.Rd    := '1';
                v.State := RdData;
                v.ToCnt := ReadTimeoutClks_g-1;

            when RdData =>
                -- Wait for read data
                if Rb_RdValid = '1' then
                    v.RData  := Rb_RdData;
                    v.RValid := '1';
                    v.RResp  := AxiResp_Okay_c;
                    v.State  := RdResp;
                end if;
                -- Timeout handling
                if v.ToCnt = 0 then
                    v.RValid := '1';
                    v.RResp  := AxiResp_SlvErr_c;
                    v.State  := RdResp;
                else
                    v.ToCnt := v.ToCnt - 1;
                end if;

            when RdResp =>
                -- Wait for response transferred
                if S_AxiLite_RReady = '1' then
                    v.State  := Idle;
                    v.RValid := '0';
                end if;

            -- coverage off
            when others => null; -- unreachable
            -- coverage on

        end case;

        -- Outputs AXI
        S_AxiLite_ArReady <= r.ArReady;
        S_AxiLite_AwReady <= r.AwReady;
        S_AxiLite_WReady  <= r.WReady;
        S_AxiLite_BResp   <= AxiResp_Okay_c; -- Writes can't fail
        S_AxiLite_BValid  <= r.BValid;
        S_AxiLite_RData   <= r.RData;
        S_AxiLite_RResp   <= r.RResp;
        S_AxiLite_RValid  <= r.RValid;

        -- Outputs RB
        Rb_Addr    <= r.Addr;
        Rb_ByteEna <= r.ByteEna;
        Rb_WrData  <= r.WrData;
        Rb_Wr      <= r.Wr;
        Rb_Rd      <= r.Rd;

        -- Assign signal
        r_next <= v;
    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.State   <= Idle;
                r.ArReady <= '0';
                r.AwReady <= '0';
                r.WReady  <= '0';
                r.Wr      <= '0';
                r.BValid  <= '0';
                r.Rd      <= '0';
                r.RValid  <= '0';
            end if;
        end if;
    end process;

end architecture;
