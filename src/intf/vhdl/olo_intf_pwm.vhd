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

        In_En     : in std_logic                                            := '1';
        In_Period : in std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0) := toUslv(MaxPeriod_g, log2Ceil(MaxPeriod_g+1));
        In_OnTime : in std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);

        Out_PeriodStart : out std_logic;
        Out_PeriodCnt   : out std_logic_vector(log2Ceil(MaxPeriod_g+1)-1 downto 0);
        Out_Pwm         : out std_logic
    );
end entity;

--------------------------------------------------------------------------------
-- Architecture Declaration
--------------------------------------------------------------------------------
architecture rtl of olo_intf_pwm is

    -- *** Two Process Method ***
    type TwoProcess_r is record
        Period : unsigned(In_Period'range);
        OnTime : unsigned(In_OnTime'range);
        --
        PeriodStart : std_logic;
        PeriodCnt   : unsigned(Out_PeriodCnt'range);
        Pwm         : std_logic;
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
        v.PeriodStart := '0';

        if (v.PeriodCnt = to_unsigned(0, r.PeriodCnt'length)) then
            -- Update values for Period and OnTime
            v.Period := unsigned(In_Period);
            v.OnTime := unsigned(In_OnTime);
        end if;

        if (In_En = '1') then
            if (v.Period = to_unsigned(0, r.Period'length)) then
                -- Don't Increment PeriodCnt if Period = 0
                v.PeriodCnt := (others => '0');

            elsif (r.PeriodCnt < r.Period - 1) then
                -- Increment Period Counter
                v.PeriodCnt := v.PeriodCnt + 1;
            else
                -- Reset Period Counter
                v.PeriodStart := '1';
                v.PeriodCnt   := (others => '0');
            end if;

        else
            -- Reset Period Counter if In_En isn't set
            v.PeriodCnt := (others => '0');
        end if;

        -- Apply to record
        r_next <= v;

    end process;

    -- Outputs
    Out_PeriodStart <= '1' when (r.PeriodCnt = 0) and (In_En = '1') else '0';
    Out_PeriodCnt   <= std_logic_vector(r.PeriodCnt);
    Out_Pwm         <=
        '1' when (r.PeriodCnt < r.OnTime) and (r_next.OnTime > 0) and (In_En = '1') else
        '0';

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if (Rst = '1') then
                r.PeriodStart <= '0';
                r.PeriodCnt   <= (others => '0');
                r.Pwm         <= '0';
            end if;
        end if;
    end process;

end architecture;