--------------------------------------------------------------------------------
-- olo_intf_pwm
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library olo;
use olo.olo_base_pkg_math.all;

--------------------------------------------------------------------------------
-- Entity Declaration
--------------------------------------------------------------------------------
entity olo_intf_pwm is
    generic(
        MaxPeriod_g : positive
    );
    port(
        Clk : in std_logic;
        Rst : in std_logic;

        ------------------------------------------------------------------------
        -- Configuration Interface
        ------------------------------------------------------------------------
        In_Valid  : in  std_logic;
        In_Ready  : out std_logic;
        In_Period : in  std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0) := toUslv(MaxPeriod_g, log2Ceil(MaxPeriod_g+1));
        In_OnTime : in  std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);

        ------------------------------------------------------------------------
        -- Pwm Interface
        ------------------------------------------------------------------------
        Out_Period    : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);
        Out_OnTime    : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);
        Out_PeriodCnt : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);
        Out_Pwm       : out std_logic
    );
end entity;

architecture rtl of olo_intf_pwm is

    constant Width_c : positive := log2Ceil(MaxPeriod_g+1);

    type UnsignedArray_t is array (natural range<>) of unsigned(Width_c - 1 downto 0);

    -- *** Two Process Method ***
    type TwoProcess_r is record
        -- Configuration Interface
        ConfigItf_Ready  : std_logic;
        ConfigItf_Period : unsigned(In_Period'range);
        ConfigItf_OnTime : unsigned(In_OnTime'range);
        ConfigItf_New    : std_logic;

        --
        ZeroPeriod : std_logic;
        ZeroOnTime : std_logic;

        -- Pwm Output Interface
        PwmItf_Period    : UnsignedArray_t(1 downto 0);
        PwmItf_OnTime    : UnsignedArray_t(1 downto 0);
        PwmItf_PeriodCnt : UnsignedArray_t(2 downto 0);
        PwmItf_Pwm       : std_logic_vector(1 downto 0);
    end record;

    signal r      : TwoProcess_r;
    signal r_next : TwoProcess_r;

begin

    -- *** Combinatorial Process ***
    p_comb : process(r, In_Valid, In_Period, In_OnTime) is
        variable v : TwoProcess_r;
    begin

        -- *** hold variables stable ***
        v := r;

        ------------------------------------------------------------------------
        -- Configuration Interface
        ------------------------------------------------------------------------
        if (In_Valid = '1' and r.ConfigItf_Ready = '1') then
            v.ConfigItf_Period := unsigned(In_Period);
            v.ConfigItf_OnTime := unsigned(In_OnTime);

            -- New Configuration availible
            v.ConfigItf_New := '1';

            v.ConfigItf_Ready := '0';
        end if;

        ------------------------------------------------------------------------
        -- Use New Configuration Values
        ------------------------------------------------------------------------
        if (r.ConfigItf_New = '1') then

            -- Change PWM Interface values when New Period Starts
            if (r.PwmItf_PeriodCnt(0) = to_unsigned(0, Out_PeriodCnt'length)) then

                v.PwmItf_Period(0) := r.ConfigItf_Period;
                v.PwmItf_OnTime(0) := r.ConfigItf_OnTime;

                -- Edge Case: Zero Period
                if (r.ConfigItf_Period = to_unsigned(0, In_Period'length)) then
                    v.ZeroPeriod := '1';
                else
                    v.ZeroPeriod := '0';
                end if;

                -- Edge Case: Zero OnTime
                if (r.ConfigItf_OnTime = to_unsigned(0, In_OnTime'length)) then
                    v.ZeroOnTime := '1';
                else
                    v.ZeroOnTime := '0';
                end if;

                -- New Configuration has been read
                v.ConfigItf_New := '0';

                -- Configuration Interface is Ready to receive new Configuration
                v.ConfigItf_Ready := '1';
            end if;

        end if;

        ------------------------------------------------------------------------
        -- Period Counter
        ------------------------------------------------------------------------
        if (r.PwmItf_PeriodCnt(0) < r.PwmItf_Period(0) - 1) then
            v.PwmItf_PeriodCnt(0) := r.PwmItf_PeriodCnt(0) + 1;
        else
            v.PwmItf_PeriodCnt(0) := (others => '0');
        end if;

        ------------------------------------------------------------------------
        -- PWM
        ------------------------------------------------------------------------
        if (r.PwmItf_PeriodCnt(0) < r.PwmItf_OnTime(0)) then
            v.PwmItf_Pwm(0) := '1';
        else
            v.PwmItf_Pwm(0) := '0';
        end if;

        ------------------------------------------------------------------------
        -- Pipeline Chains
        ------------------------------------------------------------------------
        for i in 0 to r.PwmItf_PeriodCnt'length - 2 loop
            v.PwmItf_PeriodCnt(i + 1) := r.PwmItf_PeriodCnt(i);
        end loop;

        for i in 0 to r.PwmItf_Period'length - 2 loop
            v.PwmItf_Period(i + 1) := r.PwmItf_Period(i);
        end loop;

        for i in 0 to r.PwmItf_OnTime'length - 2 loop
            v.PwmItf_OnTime(i + 1) := r.PwmItf_OnTime(i);
        end loop;

        for i in 0 to r.PwmItf_Pwm'length - 2 loop
            v.PwmItf_Pwm(i + 1) := r.PwmItf_Pwm(i);
        end loop;

        ------------------------------------------------------------------------
        -- Edge Cases
        ------------------------------------------------------------------------
        -- Reset whole Pwm Chain If OnTime or Period is Zero
        if (r.ZeroPeriod = '1' or r.ZeroOnTime = '1') then
            v.PwmItf_Pwm := (others => '0');
        end if;

        -- Reset whole PeriodCnt chain if Period is Zero
        if (r.ZeroPeriod = '1') then
            v.PwmItf_PeriodCnt := (others => (others => '0'));
        end if;

        -- Set Pwm High If 
        --      Previously Had OnTime = 0 and now OnTime /= 0 and
        --      Period /= 0 
        if (
                (r.ZeroOnTime = '1' and v.ZeroOnTime = '0') and
                r.ZeroPeriod = '0'
            ) then
            v.PwmItf_Pwm(0) := '1';
        end if;

        -- Increment Period Counter and Set Pwm High If
        --      Previously Had Period = 0 and now Period /= 0
        --      PeriodCnt = 0
        --      OnTime /= 0 
        if (
                (r.ZeroPeriod = '1' and v.ZeroPeriod = '0') and
                r.PwmItf_PeriodCnt(0) = to_unsigned(0, Width_c) and
                r.ZeroOnTime = '0'
            ) then
            v.PwmItf_PeriodCnt(0) := to_unsigned(1, Width_c);
            v.PwmItf_Pwm(0)       := '1';
        end if;

        ------------------------------------------------------------------------
        -- Apply to record
        ------------------------------------------------------------------------
        r_next <= v;

    end process;

    In_Ready <= r.ConfigItf_Ready;

    Out_Period <= std_logic_vector(r.PwmItf_Period(1));
    Out_OnTime <= std_logic_vector(r.PwmItf_OnTime(1));

    Out_PeriodCnt <= std_logic_vector(r.PwmItf_PeriodCnt(2));
    Out_Pwm       <= r.PwmItf_Pwm(1);

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if (Rst = '1') then
                -- Configuration Interface
                r.ConfigItf_Ready <= '1';

                --
                r.ZeroPeriod <= '1';
                r.ZeroOnTime <= '0';

                -- Pwm Interface
                r.PwmItf_PeriodCnt <= (others => (others => '0'));
                r.PwmItf_Pwm       <= (others => '0');
            end if;
        end if;
    end process;
end architecture;
