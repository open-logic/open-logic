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

        In_En : in std_logic := '1';

        In_Valid  : in  std_logic;
        In_Ready  : out std_logic;
        In_Period : in  std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0) := toUslv(MaxPeriod_g, log2Ceil(MaxPeriod_g+1));
        In_OnTime : in  std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);

        Out_Period : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);
        Out_OnTime : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);

        Out_PeriodCnt : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);
        Out_Pwm       : out std_logic
    );
end entity;

--------------------------------------------------------------------------------
-- Architecture Declaration
--------------------------------------------------------------------------------
architecture rtl of olo_intf_pwm is

    -- *** Two Process Method ***
    type TwoProcess_r is record
        Ready_r1 : std_logic;

        ValuesLatched_r1 : std_logic;
        PeriodLatched_r1 : unsigned(In_Period'range);
        OnTimeLatched_r1 : unsigned(In_OnTime'range);

        ValuesActive_r2 : std_logic;
        PeriodActive_r2 : unsigned(In_Period'range);
        PeriodActive_r3 : unsigned(In_Period'range);
        OnTimeActive_r2 : unsigned(In_OnTime'range);
        OnTimeActive_r3 : unsigned(In_OnTime'range);

        --
        PeriodCnt_r2 : unsigned(Out_PeriodCnt'range);
        PeriodCnt_r1 : unsigned(Out_PeriodCnt'range);
        Pwm          : std_logic;
    end record;

    signal r      : TwoProcess_r;
    signal r_next : TwoProcess_r;

begin

    -- *** Combinatorial Process ***
    p_comb : process(r, In_En, In_Period, In_OnTime) is
        variable v : TwoProcess_r;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***

        ------------------------------------------------------------------------
        -- R0
        ------------------------------------------------------------------------
        if (In_Valid = '1' and r.Ready_r1 = '1') then
            -- Update values for Period and OnTime
            v.PeriodLatched_r1 := unsigned(In_Period);
            v.OnTimeLatched_r1 := unsigned(In_OnTime);

            v.Ready_r1 := '0';

            v.ValuesLatched_r1 := '1';
        end if;

        ------------------------------------------------------------------------
        -- R1
        ------------------------------------------------------------------------
        if (r.ValuesLatched_r1 = '1') then
            if (r.PeriodCnt_r2 = to_unsigned(0, In_Period'length)) then
                v.PeriodActive_r2 := r.PeriodLatched_r1;
                v.OnTimeActive_r2 := r.OnTimeLatched_r1;

                v.ValuesActive_r2  := '1';
                v.ValuesLatched_r1 := '0';
            end if;
        end if;


        if (r.ValuesActive_r2 = '1') then
            if (r.PeriodActive_r2 = to_unsigned(0, In_Period'length)) then
                v.Ready_r1     := '1';
                v.PeriodCnt_r1 := (others => '0');
            elsif (r.PeriodCnt_r1 < r.PeriodActive_r2 - 1) then
                v.PeriodCnt_r1 := r.PeriodCnt_r1 + 1;

            else
                v.Ready_r1     := '1';
                v.PeriodCnt_r1 := (others => '0');
            end if;

        end if;


        ------------------------------------------------------------------------
        -- R2
        ------------------------------------------------------------------------

        if (r.PeriodCnt_r1 < r.OnTimeActive_r2) then
            v.Pwm := '1';
        else
            v.Pwm := '0';
        end if;


        v.PeriodCnt_r2    := r.PeriodCnt_r1;
        v.PeriodActive_r3 := r.PeriodActive_r2;
        v.OnTimeActive_r3 := r.OnTimeActive_r2;


        -- Apply to record
        r_next <= v;

    end process;

    -- Outputs
    In_Ready <= r.Ready_r1;

    Out_Period <= std_logic_vector(r.PeriodActive_r3);
    Out_OnTime <= std_logic_vector(r.OnTimeActive_r3);

    Out_PeriodCnt <= std_logic_vector(r.PeriodCnt_r2);
    Out_Pwm       <= r.Pwm;


    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if (Rst = '1') then
                r.Ready_r1         <= '1';
                r.ValuesLatched_r1 <= '0';
                r.ValuesActive_r2  <= '0';
                r.PeriodCnt_r2     <= (others => '0');
                r.PeriodCnt_r1     <= (others => '0');
                r.Pwm              <= '0';
            end if;
        end if;
    end process;

end architecture;
