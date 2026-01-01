---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a vectoring CORDIC algorithm in either pipelined or serial mode.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_cordic_vect.md
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
    use work.olo_base_pkg_string.all;
    use work.olo_base_pkg_array.all;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_cordic_vect is
    generic (
        InFmt_g           : string;
        OutMagFmt_g       : string;
        OutAngFmt_g       : string;
        IntXyFmt_g        : string  := "AUTO";
        IntAngFmt_g       : string  := "AUTO";
        Iterations_g      : natural := 16;
        Mode_g            : string  := "PIPELINED";
        GainCorrCoefFmt_g : string  := "(0,0,17)";
        Round_g           : string  := FixRound_Trunc_c;
        Saturate_g        : string  := FixSaturate_Warn_c
    );
    port (
        -- Control Signals
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Input
        In_Valid  : in    std_logic;
        In_Ready  : out   std_logic;
        In_I      : in    std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0);
        In_Q      : in    std_logic_vector(fixFmtWidthFromString(InFmt_g)-1 downto 0);
        -- Output
        Out_Valid : out   std_logic;
        Out_Mag   : out   std_logic_vector(fixFmtWidthFromString(OutMagFmt_g)-1 downto 0);
        Out_Ang   : out   std_logic_vector(fixFmtWidthFromString(OutAngFmt_g)-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_cordic_vect is

    -- String upping
    constant IntXyFmtUpper_c        : string := toUpper(IntXyFmt_g);
    constant IntAngFmtUpper_c       : string := toUpper(IntAngFmt_g);
    constant ModeUpper_c            : string := toUpper(Mode_g);
    constant GainCorrCoefFmtUpper_c : string := toUpper(GainCorrCoefFmt_g);

    -- Formats
    constant InFmt_c           : FixFormat_t   := cl_fix_format_from_string(InFmt_g);
    constant OutMagFmt_c       : FixFormat_t   := cl_fix_format_from_string(OutMagFmt_g);
    constant OutAngFmt_c       : FixFormat_t   := cl_fix_format_from_string(OutAngFmt_g);
    constant IntXyFmt_c        : FixFormat_t   := choose(IntXyFmtUpper_c = "AUTO",
                                                         (1, InFmt_c.I + 2, max(OutMagFmt_c.F, OutAngFmt_c.F - InFmt_c.I) + 4),
                                                         fixFmtFromStringTolerant(IntXyFmtUpper_c));
    constant IntAngFmt_c       : FixFormat_t   := choose(IntAngFmtUpper_c = "AUTO",
                                                         (1, -1, OutAngFmt_c.F + 3),
                                                         fixFmtFromStringTolerant(IntAngFmtUpper_c));
    constant GainCorrCoefFmt_c : FixFormat_t   := choose(GainCorrCoefFmtUpper_c = "NONE",
                                                         FixFmt_Unused_c,
                                                         fixFmtFromStringTolerant(GainCorrCoefFmtUpper_c));
    constant Round_c           : FixRound_t    := cl_fix_round_from_string(Round_g);
    constant Saturate_c        : FixSaturate_t := cl_fix_saturate_from_string(Saturate_g);

    -- For angles in scaled radians, there is no difference between unsigned or signed (two's
    -- compliment). However, AngleTableReal_c has been hard-coded as unsigned, so we force that.
    constant TableFmt_c            : FixFormat_t := (0, -2, IntAngFmt_c.F);
    -- For consistency, we also use an unsigned AngleIntFmt for other angle conversions from real.
    constant UnsignedAngleIntFmt_c : FixFormat_t := (0, 0, IntAngFmt_c.F);

    -- *** Constants ***
    constant AngleTableReal_c : RealArray_t(0 to 31) := (0.125,              0.0737918088252,    0.0389895651887,    0.0197917120803,
                                                         0.00993426215277,   0.00497197391179,   0.00248659363948,   0.00124337269683,
                                                         0.000621695834357,  0.000310849102962,  0.000155424699705,  7.77123683806e-05,
                                                         3.88561865063e-05,  1.94280935426e-05,  9.71404680751e-06,  4.85702340828e-06,
                                                         2.4285117047e-06,   1.21425585242e-06,  6.0712792622e-07,   3.03563963111e-07,
                                                         1.51781981556e-07,  7.58909907779e-08,  3.7945495389e-08,   1.89727476945e-08,
                                                         9.48637384724e-09,  4.74318692362e-09,  2.37159346181e-09,  1.1857967309e-09,
                                                         5.92898365452e-10,  2.96449182726e-10,  1.48224591363e-10,  7.41122956816e-11);
    type AngleTable_t is array (0 to Iterations_g-1) of std_logic_vector(cl_fix_width(TableFmt_c)-1 downto 0);

    function angleTableStdlv return AngleTable_t is
        variable Table_v : AngleTable_t;
    begin

        for i in 0 to Iterations_g-1 loop
            Table_v(i) := cl_fix_from_real(AngleTableReal_c(i), TableFmt_c);
        end loop;

        return Table_v;
    end function;

    constant AngleTable_c : AngleTable_t := angleTableStdlv;

    function cordicGain (iterations : integer) return real is
        variable Gain_v : real := 1.0;
    begin

        for i in 0 to iterations-1 loop
            Gain_v := Gain_v * sqrt(1.0+2.0**(-2.0*real(i)));
        end loop;

        return Gain_v;
    end function;

    constant GcCoef_c     : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c)-1 downto 0) := cl_fix_from_real(1.0/cordicGain(Iterations_g), GainCorrCoefFmt_c);
    constant AngInt_0_5_c : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0)       := cl_fix_from_real(0.5, UnsignedAngleIntFmt_c);
    constant AngInt_1_0_c : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0)       := cl_fix_from_real(0.0, UnsignedAngleIntFmt_c);

    -- *** Functions ***
    -- Cordic step for X
    function cordicStepx (
        xLast       : std_logic_vector;
        yLast       : std_logic_vector;
        shift       : integer) return std_logic_vector is
        -- Declarations
        constant YShifted_c : std_logic_vector := cl_fix_shift(yLast, IntXyFmt_c, -shift, IntXyFmt_c, Trunc_s, None_s);
    begin

        if signed(yLast) < 0 then
            return cl_fix_sub(xLast, IntXyFmt_c,
                              YShifted_c, IntXyFmt_c,
                              IntXyFmt_c, Trunc_s, None_s);
        else
            return cl_fix_add(xLast, IntXyFmt_c,
                              YShifted_c, IntXyFmt_c,
                              IntXyFmt_c, Trunc_s, None_s);

        end if;
    end function;

    -- Cordic step for Y
    function cordicStepy (
        xLast       : std_logic_vector;
        yLast       : std_logic_vector;
        shift       : integer) return std_logic_vector is
        -- Declarations
        constant XShifted_c : std_logic_vector := cl_fix_shift(xLast, IntXyFmt_c, -shift, IntXyFmt_c, Trunc_s, None_s);
    begin

        if signed(yLast) < 0 then
            return  cl_fix_add(yLast, IntXyFmt_c,
                               XShifted_c, IntXyFmt_c,
                               IntXyFmt_c, Trunc_s, None_s);
        else
            return  cl_fix_sub(yLast, IntXyFmt_c,
                               XShifted_c, IntXyFmt_c,
                               IntXyFmt_c, Trunc_s, None_s);
        end if;
    end function;

    -- Cordic step for Z
    function cordicStepz (
        zLast       : std_logic_vector;
        yLast       : std_logic_vector;
        iteration   : integer) return std_logic_vector is
        -- Declarations
        constant Atan_c : std_logic_vector(cl_fix_width(TableFmt_c)-1 downto 0) := AngleTable_c(iteration);
    begin
        if signed(yLast) < 0 then
            return  cl_fix_sub(zLast, IntAngFmt_c,
                               Atan_c, TableFmt_c,
                               IntAngFmt_c, Trunc_s, None_s);
        else
            return  cl_fix_add(zLast, IntAngFmt_c,
                               Atan_c, TableFmt_c,
                               IntAngFmt_c, Trunc_s, None_s);
        end if;
    end function;

    -- Types
    type IntArr_t is array (natural range <>) of std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
    type AngArr_t is array (natural range <>) of std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0);

    -- Gain Correction Signals
    signal GcAng : std_logic_vector(cl_fix_width(OutAngFmt_c)-1 downto 0);
    signal GcMag : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
    signal GcVld : std_logic;

begin

    -- *** Assertions ***
    assert InFmt_c.S = 1
        report "###ERROR###: olo_fix_cordic_vect: InFmt_g must be signed"
        severity error;
    assert OutMagFmt_c.S = 0
        report "###ERROR###: olo_fix_cordic_vect: OutMagFmt_g must be unsigned"
        severity error;
    assert OutAngFmt_c.S + OutAngFmt_c.I = 0
        report "###ERROR###: olo_fix_cordic_vect: OutAngFmt_g must be (0, 0, x)"
        severity error;
    assert IntXyFmt_c.S = 1
        report "###ERROR###: olo_fix_cordic_vect: IntXyFmt_g must be signed"
        severity error;
    assert IntAngFmt_c.S = 1
        report "###ERROR###: olo_fix_cordic_vect: IntAngFmt_g must be signed"
        severity error;
    assert IntAngFmt_c.I = -1
        report "###ERROR###: olo_fix_cordic_vect: IntAngFmt_g must be (1,-1,x)"
        severity error;
    assert Iterations_g <= 32
        report "###ERROR###: olo_fix_cordic_rot: Iterations_g must be <= 32"
        severity error;
    assert ModeUpper_c = "PIPELINED" or ModeUpper_c = "SERIAL"
        report "###ERROR###: olo_fix_cordic_rot: Mode_g must be PIPELINED or SERIAL"
        severity error;

    -- *** Pipelined Implementation ***
    g_pipelined : if ModeUpper_c = "PIPELINED" generate
        signal IReg, Qreg : std_logic_vector(cl_fix_width(InFmt_c)-1 downto 0);
        signal VldReg     : std_logic;
        signal X, Y       : IntArr_t(0 to Iterations_g);
        signal Z          : AngArr_t(0 to Iterations_g);
        signal Vld        : std_logic_vector(0 to Iterations_g);
        signal Quad       : StlvArray2_t(0 to Iterations_g);
    begin
        -- Pipelined implementation can take a sample every clock cycle
        In_Ready <= '1';

        -- Implementation
        p_cordic_pipelined : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Input registering
                VldReg <= In_Valid;
                IReg   <= In_I;
                Qreg   <= In_Q;

                -- Map to quadrant one
                -- No rounding or saturation because IntXyFmt_c is checked to have sufficient int and frac bits
                X(0)    <= cl_fix_abs(IReg, InFmt_c, IntXyFmt_c, Trunc_s, None_s);
                Y(0)    <= cl_fix_abs(Qreg, InFmt_c, IntXyFmt_c, Trunc_s, None_s);
                Z(0)    <= (others => '0');
                Quad(0) <= IReg(IReg'left) & Qreg(Qreg'left);
                Vld(0)  <= VldReg;

                -- Cordic Iterations_g
                Vld(1 to Vld'high)   <= Vld(0 to Vld'high-1);
                Quad(1 to Quad'high) <= Quad(0 to Quad'high-1);

                for i in 0 to Iterations_g-1 loop
                    X(i+1) <= cordicStepx(X(i), Y(i), i);
                    Y(i+1) <= cordicStepy(X(i), Y(i), i);
                    Z(i+1) <= cordicStepz(Z(i), Y(i), i);
                end loop;

                -- Output
                GcVld <= Vld(Iterations_g);
                GcMag <= X(Iterations_g);

                case Quad(Iterations_g) is
                    -- Normalized angles are never saturated. With 1 non-fractional bit, wrapping is correct behavior.
                    when "00" => GcAng <= cl_fix_resize(Z(Iterations_g), IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    when "10" => GcAng <= cl_fix_sub(AngInt_0_5_c, IntAngFmt_c, Z(Iterations_g), IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    when "11" => GcAng <= cl_fix_add(AngInt_0_5_c, IntAngFmt_c, Z(Iterations_g), IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    when "01" => GcAng <= cl_fix_sub(AngInt_1_0_c, IntAngFmt_c, Z(Iterations_g), IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    -- coverage off
                    when others => null; -- unreachable
                    -- coverage on
                end case;

                -- Reset
                if Rst = '1' then
                    Vld    <= (others => '0');
                    VldReg <= '0';
                    GcVld  <= '0';
                end if;
            end if;
        end process;

    end generate;

    -- *** Serial Implementation ***
    g_serial : if ModeUpper_c = "SERIAL" generate
        -- Signals
        signal Xin, Yin  : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
        signal XIn_Valid : std_logic;
        signal Quadin    : std_logic_vector(1 downto 0);
        signal X, Y      : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
        signal Z         : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0);
        signal CordVld   : std_logic;
        signal IterCnt   : integer range 0 to Iterations_g-1;
        signal Quad      : std_logic_vector(1 downto 0);

        -- Constants
        constant Z0_c : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0) := (others => '0');
    begin
        In_Ready <= not XIn_Valid;

        p_cordic_serial : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Input latching
                if XIn_Valid = '0' and In_Valid = '1' then
                    XIn_Valid <= '1';
                    -- Map to quadrant one
                    -- No rounding or saturation because IntXyFmt_c is checked to have sufficient int and frac bits
                    Xin    <= cl_fix_abs(In_I, InFmt_c, IntXyFmt_c, Trunc_s, None_s);
                    Yin    <= cl_fix_abs(In_Q, InFmt_c, IntXyFmt_c, Trunc_s, None_s);
                    Quadin <= In_I(In_I'left) & In_Q(In_Q'left);
                end if;

                -- CORDIC loop
                CordVld <= '0';
                if IterCnt = 0 then
                    -- Start of calculation
                    if XIn_Valid = '1' then
                        Y         <= cordicStepy(Xin, Yin, 0);
                        X         <= cordicStepx(Xin, Yin, 0);
                        Quad      <= Quadin;
                        Z         <= cordicStepz(Z0_c, Yin, 0);
                        IterCnt   <= IterCnt+1;
                        XIn_Valid <= '0';
                    end if;
                else
                    -- Normal Calculation Step
                    X <= cordicStepx(X, Y, IterCnt);
                    Y <= cordicStepy(X, Y, IterCnt);
                    Z <= cordicStepz(Z, Y, IterCnt);

                    if IterCnt = Iterations_g-1 then
                        IterCnt <= 0;
                        CordVld <= '1';
                    else
                        IterCnt <= IterCnt+1;
                    end if;
                end if;

                -- Output
                GcVld <= CordVld;
                GcMag <= X;

                case Quad is
                    -- Normalized angles are never saturated. With 1 non-fractional bit, wrapping is correct behavior.
                    when "00" => GcAng <= cl_fix_resize(Z, IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    when "10" => GcAng <= cl_fix_sub(AngInt_0_5_c, IntAngFmt_c, Z, IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    when "11" => GcAng <= cl_fix_add(AngInt_0_5_c, IntAngFmt_c, Z, IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    when "01" => GcAng <= cl_fix_sub(AngInt_1_0_c, IntAngFmt_c, Z, IntAngFmt_c, OutAngFmt_c, Trunc_s, None_s);
                    -- coverage off
                    when others => null; -- unreachable
                    -- coverage on
                end case;

                -- Reset
                if Rst = '1' then
                    XIn_Valid <= '0';
                    IterCnt   <= 0;
                    GcVld     <= '0';
                    CordVld   <= '0';
                end if;
            end if;
        end process;

    end generate;

    -- *** Gain Correction ***
    -- No correction
    g_no_gain_comp : if GainCorrCoefFmtUpper_c = "NONE" generate

        -- Resize Magnitued
        i_resize_mag : entity work.olo_fix_resize
            generic map (
                AFmt_g      => to_string(IntXyFmt_c),
                ResultFmt_g => to_string(OutMagFmt_c),
                Round_g     => to_string(Round_c),
                Saturate_g  => to_string(Saturate_c),
                RoundReg_g  => "YES",
                SatReg_g    => "YES"
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => GcVld,
                In_A        => GcMag,
                Out_Valid   => Out_Valid,
                Out_Result  => Out_Mag
            );

        -- Delay Angle
        i_delay_angle : entity work.olo_base_delay
            generic map (
                Width_g         => cl_fix_width(OutAngFmt_c),
                Delay_g         => 2,
                RstState_g      => false
            )
            port map (
                Clk      => Clk,
                Rst      => Rst,
                In_Data  => GcAng,
                Out_Data => Out_Ang
            );

    end generate;

    -- Compensation Enabled
    g_gain_comp : if GainCorrCoefFmtUpper_c /= "NONE" generate

        i_mult_mag : entity work.olo_fix_mult
            generic map (
                AFmt_g      => to_string(IntXyFmt_c),
                BFmt_g      => to_string(GainCorrCoefFmt_c),
                ResultFmt_g => to_string(OutMagFmt_c),
                Round_g     => to_string(Round_c),
                Saturate_g  => to_string(Saturate_c),
                RoundReg_g  => "YES",
                SatReg_g    => "YES",
                OpRegs_g    => 1
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => GcVld,
                In_A        => GcMag,
                In_B        => GcCoef_c,
                Out_Valid   => Out_Valid,
                Out_Result  => Out_Mag
            );

        -- Delay Angle
        i_delay_angle : entity work.olo_base_delay
            generic map (
                Width_g         => cl_fix_width(OutAngFmt_c),
                Delay_g         => 3,
                RstState_g      => false
            )
            port map (
                Clk      => Clk,
                Rst      => Rst,
                In_Data  => GcAng,
                Out_Data => Out_Ang
            );

    end generate;

end architecture;
