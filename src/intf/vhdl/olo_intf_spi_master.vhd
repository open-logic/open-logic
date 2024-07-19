------------------------------------------------------------------------------
--	Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler, Switzerland
--	All rights reserved.
--  Authors: Oliver Bruendler, Franz Herzog
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This entity implements a simple SPI-master

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_logic.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity olo_intf_spi_master is
    generic (
        ClkFreq_g       : real;
        SclkFreq_g      : real                      := 1.0e6;
        MaxTransWidth_g : positive                  := 32;
        CsHighTime_g    : real                      := 20.0e-9;
        SpiCPOL_g       : natural range 0 to 1      := 1;
        SpiCPHA_g       : natural range 0 to 1      := 1;
        SlaveCnt_g      : positive                  := 1;
        LsbFirst_g      : boolean                   := false;
        MosiIdleState_g : std_logic                 := '0'
    );
    port (
        -- Control Signals
        Clk        : in  std_logic; 
        Rst        : in  std_logic;
        -- Parallel Interface
        Start      : in  std_logic;
        Slave      : in  std_logic_vector(log2ceil(SlaveCnt_g) - 1 downto 0)        := (others => '0');
        Busy       : out std_logic;
        Done       : out std_logic;
        WrData     : in  std_logic_vector(MaxTransWidth_g - 1 downto 0)             := (others => '0');
        RdData     : out std_logic_vector(MaxTransWidth_g - 1 downto 0);
        TransWidth : in  std_logic_vector(log2ceil(MaxTransWidth_g+1)-1 downto 0)   := toUslv(MaxTransWidth_g, log2ceil(MaxTransWidth_g+1));
        -- SPI 
        SpiSclk    : out std_logic;
        SpiMosi    : out std_logic;
        SpiMiso    : in  std_logic                                                   := '0';
        SpiCs_n    : out std_logic_vector(SlaveCnt_g - 1 downto 0)
    );
end entity;

------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of olo_intf_spi_master is

    -- *** Types ***
    type State_t is (Idle_s, SftComp_s, ClkInact_s, ClkAct_s, CsHigh_s);

    -- *** Constants ***
    constant ClkDiv_c         : natural := integer(round(ClkFreq_g/SclkFreq_g));
    constant ClkDivThres_c    : natural := ClkDiv_c / 2 - 1;
    constant CsHighCycles_c   : natural := integer(ceil(ClkFreq_g*CsHighTime_g));
    constant SclkFreqResult_c : real    := ClkFreq_g/(2.0*real(ClkDivThres_c+1));

    -- *** Two Process Method ***
    type two_process_r is record
        State     : State_t;
        StateLast : State_t;
        ShiftReg  : std_logic_vector(MaxTransWidth_g - 1 downto 0);
        RdData    : std_logic_vector(MaxTransWidth_g - 1 downto 0);
        SpiCs_n   : std_logic_vector(SlaveCnt_g - 1 downto 0);
        SpiSclk    : std_logic;
        SpiMosi   : std_logic;
        ClkDivCnt : integer range 0 to ClkDivThres_c;
        BitCnt    : integer range 0 to MaxTransWidth_g;
        CsHighCnt : integer range 0 to CsHighCycles_c - 1;
        Busy      : std_logic;
        Done      : std_logic;
        MosiNext  : std_logic;
        TransWidth: std_logic_vector(log2ceil(MaxTransWidth_g) downto 0);
    end record;
    signal r, r_next : two_process_r;

    -- *** Functions and procedures ***
    function GetClockLevel(ClkActive : boolean) return std_logic is
    begin
        if SpiCPOL_g = 0 then
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

    procedure ShiftReg(signal BeforeShift  : in std_logic_vector(MaxTransWidth_g-1 downto 0);
                       variable AfterShift : out std_logic_vector(MaxTransWidth_g-1 downto 0);
                       signal InputBit     : in std_logic;
                       variable OutputBit  : out std_logic) is
    begin
        if LsbFirst_g then
            OutputBit  := BeforeShift(0);
            AfterShift := InputBit & BeforeShift(BeforeShift'high downto 1);
        else
            OutputBit  := BeforeShift(BeforeShift'high);
            AfterShift := BeforeShift(BeforeShift'high - 1 downto 0) & InputBit;
        end if;
    end procedure;

begin
    --------------------------------------------------------------------------
    -- Assertions
    --------------------------------------------------------------------------
    assert abs(SclkFreqResult_c/SclkFreq_g - 1.0) < 0.1 report "###ERROR###: olo_intf_spi_master - SclkFreq_g is not within 10% of the actual Sclk frequency" severity error;

    --------------------------------------------------------------------------
    -- Combinatorial Proccess
    --------------------------------------------------------------------------
    p_comb : process(r, Start, WrData, SpiMiso, Slave, TransWidth)
        variable v : two_process_r;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***
        v.Done := '0';

        -- *** State Machine ***
        case r.State is
            when Idle_s =>
                -- Start of Transfer
                if Start = '1' then
                    v.ShiftReg                             := WrData;
                    v.SpiCs_n(to_integer(unsigned(Slave))) := '0';
                    v.State                                := SftComp_s;
                    v.Busy                                 := '1';
                    v.TransWidth                           := TransWidth;
                end if;
                v.CsHighCnt := 0;
                v.ClkDivCnt := 0;
                v.BitCnt    := 0;

            when SftComp_s =>
                v.State := ClkInact_s;
                -- Compensate shift for CPHA 0
                if SpiCPHA_g = 0 then
                    ShiftReg(r.ShiftReg, v.ShiftReg, SpiMiso, v.MosiNext);
                end if;

            when ClkInact_s =>
                v.SpiSclk := GetClockLevel(false);
                -- Apply/Latch data if required
                if r.ClkDivCnt = 0 then
                    if SpiCPHA_g = 0 then
                        v.SpiMosi := r.MosiNext;
                    else
                        ShiftReg(r.ShiftReg, v.ShiftReg, SpiMiso, v.MosiNext);
                    end if;
                end if;
                -- Clock period handling
                if r.ClkDivCnt = ClkDivThres_c then
                    -- All bits done
                    if r.BitCnt = to_integer(unsigned(r.TransWidth)) then
                        v.SpiMosi := MosiIdleState_g;
                        v.State   := CsHigh_s;
                    -- Otherwise contintue
                    else
                        v.State := ClkAct_s;
                    end if;
                    v.ClkDivCnt := 0;
                else
                    v.ClkDivCnt := r.ClkDivCnt + 1;
                end if;

            when ClkAct_s =>
                v.SpiSclk := GetClockLevel(true);
                -- Apply data if required
                if r.ClkDivCnt = 0 then
                    if SpiCPHA_g = 1 then
                        v.SpiMosi := r.MosiNext;
                    else
                        ShiftReg(r.ShiftReg, v.ShiftReg, SpiMiso, v.MosiNext);
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
                v.SpiCs_n := (others => '1');
                if r.CsHighCnt = CsHighCycles_c - 1 then
                    v.State  := Idle_s;
                    v.Busy   := '0';
                    v.Done   := '1';
                    v.RdData := r.ShiftReg;
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

    --------------------------------------------------------------------------
    -- Outputs
    --------------------------------------------------------------------------
    Busy    <= r.Busy;
    Done    <= r.Done;
    RdData  <= r.RdData;
    SpiSclk  <= r.SpiSclk;
    SpiCs_n <= r.SpiCs_n;
    SpiMosi <= r.SpiMosi;

    --------------------------------------------------------------------------
    -- Sequential Proccess
    --------------------------------------------------------------------------
    p_seq : process(Clk)
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.State   <= Idle_s;
                r.SpiCs_n <= (others => '1');
                r.SpiSclk  <= GetClockLevel(false);
                r.Busy    <= '0';
                r.Done    <= '0';
                r.SpiMosi <= MosiIdleState_g;
            end if;
        end if;
    end process;

end;

