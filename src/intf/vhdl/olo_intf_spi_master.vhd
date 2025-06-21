---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bründler, Switzerland
-- All rights reserved.
-- Authors: Oliver Bruendler, Franz Herzog
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a simple SPI-master
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/intf/olo_intf_spi_master.md
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
    use work.olo_base_pkg_attribute.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_intf_spi_master is
    generic (
        ClkFreq_g       : real;
        SclkFreq_g      : real                 := 1.0e6;
        MaxTransWidth_g : positive             := 32;
        CsHighTime_g    : real                 := 20.0e-9;
        SpiCpol_g       : natural range 0 to 1 := 1;
        SpiCpha_g       : natural range 0 to 1 := 1;
        SlaveCnt_g      : positive             := 1;
        LsbFirst_g      : boolean              := false;
        MosiIdleState_g : std_logic            := '0'
    );
    port (
        -- Control Signals
        Clk             : in    std_logic;
        Rst             : in    std_logic;
        -- Command Interface
        Cmd_Valid       : in    std_logic;
        Cmd_Ready       : out   std_logic;
        Cmd_Slave       : in    std_logic_vector(log2ceil(SlaveCnt_g) - 1 downto 0)      := (others => '0');
        Cmd_Data        : in    std_logic_vector(MaxTransWidth_g - 1 downto 0)           := (others => '0');
        Cmd_TransWidth  : in    std_logic_vector(log2ceil(MaxTransWidth_g+1)-1 downto 0) := toUslv(MaxTransWidth_g, log2ceil(MaxTransWidth_g+1));
        -- Response Interface
        Resp_Valid      : out   std_logic;
        Resp_Data       : out   std_logic_vector(MaxTransWidth_g - 1 downto 0);
        -- SPI
        Spi_Sclk        : out   std_logic;
        Spi_Mosi        : out   std_logic;
        Spi_Miso        : in    std_logic                                                := '0';
        Spi_Cs_n        : out   std_logic_vector(SlaveCnt_g - 1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_intf_spi_master is

    -- *** Types ***
    type State_t is (Idle_s, SftComp_s, ClkInact_s, ClkAct_s, CsHigh_s);

    -- *** Constants ***
    constant ClkDiv_c         : natural := integer(round(ClkFreq_g/SclkFreq_g));
    constant ClkDivThres_c    : natural := ClkDiv_c / 2 - 1;
    constant CsHighCycles_c   : natural := integer(ceil(ClkFreq_g*CsHighTime_g));
    constant SclkFreqResult_c : real    := ClkFreq_g/(2.0*real(ClkDivThres_c+1));

    -- *** Two Process Method ***
    type TwoProcess_r is record
        State      : State_t;
        StateLast  : State_t;
        shiftReg   : std_logic_vector(MaxTransWidth_g - 1 downto 0);
        RdData     : std_logic_vector(MaxTransWidth_g - 1 downto 0);
        Spi_Cs_n   : std_logic_vector(SlaveCnt_g - 1 downto 0);
        Spi_Sclk   : std_logic;
        Spi_Mosi   : std_logic;
        ClkDivCnt  : integer range 0 to ClkDivThres_c;
        BitCnt     : integer range 0 to MaxTransWidth_g;
        CsHighCnt  : integer range 0 to CsHighCycles_c - 1;
        Busy       : std_logic;
        Done       : std_logic;
        MosiNext   : std_logic;
        TransWidth : integer range 0 to MaxTransWidth_g;
    end record;

    signal r, r_next : TwoProcess_r;

    -- Signal required for automatic constraining
    signal SpiMiso_i : std_logic;

    -- Synthesis attributes - preserve register
    attribute dont_merge of SpiMiso_i   : signal is DontMerge_SuppressChanges_c;
    attribute preserve of SpiMiso_i     : signal is Preserve_SuppressChanges_c;
    attribute keep of SpiMiso_i         : signal is Keep_SuppressChanges_c;
    attribute dont_touch of SpiMiso_i   : signal is DontTouch_SuppressChanges_c;
    attribute syn_keep of SpiMiso_i     : signal is SynKeep_SuppressChanges_c;
    attribute syn_preserve of SpiMiso_i : signal is SynPreserve_SuppressChanges_c;

    -- *** Functions and procedures ***
    function getClockLevel (ClkActive : boolean) return std_logic is
    begin
        if SpiCpol_g = 0 then
            if ClkActive then
                return '1';
            else
                return '0';
            end if;
        else
            if ClkActive then
                return '0';
            else
                return '1';
            end if;
        end if;
    end function;

    procedure shiftReg (
        signal BeforeShift  : in std_logic_vector(MaxTransWidth_g-1 downto 0);
        variable AfterShift : out std_logic_vector(MaxTransWidth_g-1 downto 0);
        signal InputBit     : in std_logic;
        variable OutputBit  : out std_logic;
        TransWidth          : in integer range 0 to MaxTransWidth_g) is
    begin
        if LsbFirst_g then
            OutputBit                := BeforeShift(0);
            AfterShift               := '0' & BeforeShift(BeforeShift'high downto 1);
            AfterShift(TransWidth-1) := InputBit;
        else
            OutputBit  := BeforeShift(TransWidth-1);
            AfterShift := BeforeShift(BeforeShift'high - 1 downto 0) & InputBit;
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- Assertions
    -----------------------------------------------------------------------------------------------
    assert abs(SclkFreqResult_c/SclkFreq_g - 1.0) < 0.1
        report "###ERROR###: olo_intf_spi_master - SclkFreq_g is not within 10% of the actual Sclk frequency"
        severity error;

    -----------------------------------------------------------------------------------------------
    -- Combinatorial Proccess
    -----------------------------------------------------------------------------------------------
    SpiMiso_i <= Spi_Miso;

    p_comb : process (all) is
        variable v : TwoProcess_r;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***
        v.Done := '0';

        -- *** State Machine ***
        case r.State is
            when Idle_s =>
                -- Start of Transfer
                if Cmd_Valid = '1' then
                    v.shiftReg                                  := Cmd_Data;
                    v.Spi_Cs_n(to_integer(unsigned(Cmd_Slave))) := '0';
                    v.State                                     := SftComp_s;
                    v.Busy                                      := '1';
                    v.TransWidth                                := fromUslv(Cmd_TransWidth);
                end if;
                v.CsHighCnt := 0;
                v.ClkDivCnt := 0;
                v.BitCnt    := 0;

            when SftComp_s =>
                v.State := ClkInact_s;
                -- Compensate shift for CPHA 0
                if SpiCpha_g = 0 then
                    shiftReg(r.shiftReg, v.shiftReg, SpiMiso_i, v.MosiNext, r.TransWidth);
                end if;

            when ClkInact_s =>
                v.Spi_Sclk := getClockLevel(false);
                -- Apply/Latch data if required
                if r.ClkDivCnt = 0 then
                    if SpiCpha_g = 0 then
                        v.Spi_Mosi := r.MosiNext;
                    else
                        shiftReg(r.shiftReg, v.shiftReg, SpiMiso_i, v.MosiNext, r.TransWidth);
                    end if;
                end if;
                -- Clock period handling
                if r.ClkDivCnt = ClkDivThres_c then
                    -- All bits done
                    if r.BitCnt = r.TransWidth then
                        v.Spi_Mosi := MosiIdleState_g;
                        v.State    := CsHigh_s;
                    -- Otherwise contintue
                    else
                        v.State := ClkAct_s;
                    end if;
                    v.ClkDivCnt := 0;
                else
                    v.ClkDivCnt := r.ClkDivCnt + 1;
                end if;

            when ClkAct_s =>
                v.Spi_Sclk := getClockLevel(true);
                -- Apply data if required
                if r.ClkDivCnt = 0 then
                    if SpiCpha_g = 1 then
                        v.Spi_Mosi := r.MosiNext;
                    else
                        shiftReg(r.shiftReg, v.shiftReg, SpiMiso_i, v.MosiNext, r.TransWidth);
                    end if;
                end if;
                -- Clock period handling
                if r.ClkDivCnt = ClkDivThres_c then
                    v.State     := ClkInact_s;
                    v.ClkDivCnt := 0;
                    v.BitCnt    := r.BitCnt + 1;
                else
                    v.ClkDivCnt := r.ClkDivCnt + 1;
                end if;

            when CsHigh_s =>
                v.Spi_Cs_n := (others => '1');
                if r.CsHighCnt = CsHighCycles_c - 1 then
                    v.State  := Idle_s;
                    v.Busy   := '0';
                    v.Done   := '1';
                    v.RdData := r.shiftReg;
                else
                    v.CsHighCnt := r.CsHighCnt + 1;
                end if;

            -- coverage off
            when others => null; -- unreachable code
            -- coverage on
        end case;

        -- *** assign signal ***
        r_next <= v;
    end process;

    -----------------------------------------------------------------------------------------------
    -- Outputs
    -----------------------------------------------------------------------------------------------
    Cmd_Ready  <= not r.Busy;
    Resp_Valid <= r.Done;
    Resp_Data  <= r.RdData;
    Spi_Sclk   <= r.Spi_Sclk;
    Spi_Cs_n   <= r.Spi_Cs_n;
    Spi_Mosi   <= r.Spi_Mosi;

    -----------------------------------------------------------------------------------------------
    -- Sequential Proccess
    -----------------------------------------------------------------------------------------------
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.State    <= Idle_s;
                r.Spi_Cs_n <= (others => '1');
                r.Spi_Sclk <= getClockLevel(false);
                r.Busy     <= '0';
                r.Done     <= '0';
                r.Spi_Mosi <= MosiIdleState_g;
            end if;
        end if;
    end process;

end architecture;

