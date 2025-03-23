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
use olo.olo_base_pkg_logic.all;
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

        In_En     : in std_logic                                          := '1';
        In_Period : in std_logic_vector(log2Ceil(MaxPeriod_g)-1 downto 0) := toUslv(MaxPeriod_g, log2Ceil(MaxPeriod_g));
        In_Duty   : in std_logic_vector(log2Ceil(MaxPeriod_g)-1 downto 0);

        Out_PeriodStart : out std_logic;
        Out_PeriodCnt   : out std_logic_vector(log2Ceil(MaxPeriod_g)-1 downto 0);
        Out_Pwm         : out std_logic
    );
end entity;

--------------------------------------------------------------------------------
-- Architecture Declaration
--------------------------------------------------------------------------------
architecture rtl of olo_intf_pwm is

    -- *** Types ***
    type State_t is (
            Idle_s,
            On_s,
            Off_s
        );

    -- *** Two Process Method ***
    type TwoProcess_r is record
        PeriodStart : std_logic;
        PeriodCnt   : unsigned(Out_PeriodCnt'range);
        Pwm         : std_logic;
        --
        State : State_t;
    end record;

    constant TwoProcessInit_c : TwoProcess_r := (
            PeriodStart => '0',
            PeriodCnt   => (others => '0'),
            Pwm         => '0',
            --
            State => Idle_s
        );

    signal r      : TwoProcess_r;
    signal r_next : TwoProcess_r;

begin

    -- *** Combinatorial Process ***
    p_comb : process(r, In_En, In_Period, In_Duty) is
        variable v : TwoProcess_r;
    begin
        -- *** hold variables stable ***
        v := r;

        -- *** Default Values ***
        v.PeriodStart := '0';

        -- *** State Machine ***
        case (r.State) is
            --------------------------------------------------------------------
            when Idle_s =>
                v.Pwm := '0';

                v.PeriodCnt := (others => '0');

                if (In_En = '1') then
                    -- Decide which state is next
                    -- (Edge case: Out_Pwm always low)
                    if (unsigned(In_Duty) * unsigned(In_Period) < MaxPeriod_g) then
                        v.Pwm := '0';
                        --
                        v.State := Off_s;
                    else
                        v.Pwm := '1';
                        --
                        v.State := On_s;
                    end if;
                end if;

            --------------------------------------------------------------------
            when On_s =>
                v.Pwm := '1';

                v.PeriodCnt := r.PeriodCnt + 1;

                -- (Edge case: Out_Pwm always low)
                if (unsigned(In_Duty) * unsigned(In_Period) < MaxPeriod_g) then
                    v.Pwm := '0';
                    --
                    v.State := Off_s;

                -- Check if Period expired (Edge case: Out_Pwm always high)
                elsif (r.PeriodCnt = unsigned(In_Period) - 1) then
                    v.PeriodStart := '1';
                    v.PeriodCnt   := (others => '0');

                -- Check if Out_Pwm should be high
                --   Modified version of the following equation, which avoids division:
                --   r.PeriodCnt >= In_Period * (In_Duty / MaxPeriod_g) - 1
                elsif (r.PeriodCnt * MaxPeriod_g >= unsigned(In_Period) * unsigned(In_Duty) - MaxPeriod_g) then
                    v.Pwm := '0';
                    --
                    v.State := Off_s;
                end if;

            --------------------------------------------------------------------
            when Off_s =>
                v.Pwm := '0';

                v.PeriodCnt := r.PeriodCnt + 1;

                -- (Edge case: Out_Pwm always low)
                if (fromUslv(In_Period) = 0) then
                    v.PeriodCnt := (others => '0');

                -- Check if Period expired
                elsif (r.PeriodCnt >= unsigned(In_Period) - 1) then
                    v.PeriodStart := '1';
                    v.PeriodCnt   := (others => '0');

                    -- Check if at least one clock cycle Out_Pwm should be high
                    if (unsigned(In_Duty) * unsigned(In_Period) >= MaxPeriod_g) then
                        v.Pwm := '1';
                        --
                        v.State := On_s;

                    -- (Edge case: Out_Pwm always low)
                    else
                        v.Pwm := '0';
                        --
                        v.State := Off_s;
                    end if;

                -- Edge case:
                --  Check if In_Period and In_Duty values changed in the middle of the current
                --  period in such a way, that Out_Pwm should actually be high
                elsif (
                        (r.PeriodCnt * MaxPeriod_g < unsigned(In_Period) * unsigned(In_Duty) - MaxPeriod_g) and
                        (unsigned(In_Duty) * unsigned(In_Period) >= MaxPeriod_g)
                    ) then
                    v.Pwm       := '1';
                    v.PeriodCnt := (others => '0');
                    --
                    v.State := On_s;
                end if;

            --------------------------------------------------------------------
            when others =>
                v := TwoProcessInit_c;
        end case;

        if (In_En = '0') then
            v.Pwm := '0';
            --
            v.State := Idle_s;
        end if;

        if (Rst = '1') then
            v := TwoProcessInit_c;
        end if;

        r_next <= v;

        -- Outputs
        Out_PeriodStart <= r.PeriodStart;
        Out_PeriodCnt   <= std_logic_vector(r.PeriodCnt);
        Out_Pwm         <= r.Pwm;

    end process;

    -- *** Sequential Process ***
    p_seq : process (Clk) is
    begin
        if rising_edge(Clk) then
            r <= r_next;
        end if;
    end process;

end architecture;