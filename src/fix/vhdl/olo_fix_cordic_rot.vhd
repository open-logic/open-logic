---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2025 by Oliver Bruendler
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements a rotating CORDIC algorithm in either pipelined or serial mode.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_cordic_rot.md
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
entity olo_fix_cordic_rot is
    generic (
        InMagFmt_g        : string;
        InAngFmt_g        : string;
        OutFmt_g          : string;
        IntXyFmt_g        : string   := "AUTO";
        IntAngFmt_g       : string   := "AUTO";
        Iterations_g      : positive := 16;
        Mode_g            : string   := "PIPELINED";
        GainCorrCoefFmt_g : string   := "(0,0,17)";
        Round_g           : string   := FixRound_Trunc_c;
        Saturate_g        : string   := FixSaturate_Warn_c
    );
    port (
        -- Control Signals
        Clk       : in    std_logic;
        Rst       : in    std_logic;
        -- Input
        In_Valid  : in    std_logic;
        In_Ready  : out   std_logic;
        In_Mag    : in    std_logic_vector(fixFmtWidthFromString(InMagFmt_g)-1 downto 0);
        In_Ang    : in    std_logic_vector(fixFmtWidthFromString(InAngFmt_g)-1 downto 0);
        -- Output
        Out_Valid : out   std_logic;
        Out_I     : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0);
        Out_Q     : out   std_logic_vector(fixFmtWidthFromString(OutFmt_g)-1 downto 0)
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture Declaration
---------------------------------------------------------------------------------------------------
architecture rtl of olo_fix_cordic_rot is

    -- String upping
    constant IntXyFmtUpper_c        : string := toUpper(IntXyFmt_g);
    constant IntAngFmtUpper_c       : string := toUpper(IntAngFmt_g);
    constant ModeUpper_c            : string := toUpper(Mode_g);
    constant GainCorrCoefFmtUpper_c : string := toUpper(GainCorrCoefFmt_g);

    -- Formats
    constant InMagFmt_c        : FixFormat_t   := cl_fix_format_from_string(InMagFmt_g);
    constant InAngFmt_c        : FixFormat_t   := cl_fix_format_from_string(InAngFmt_g);
    constant OutFmt_c          : FixFormat_t   := cl_fix_format_from_string(OutFmt_g);
    constant IntXyFmt_c        : FixFormat_t   := choose(IntXyFmtUpper_c = "AUTO",
                                                         (1, InMagFmt_c.I + 1, InMagFmt_c.F + 3),
                                                         fixFmtFromStringTolerant(IntXyFmtUpper_c));
    constant IntAngFmt_c       : FixFormat_t   := choose(IntAngFmtUpper_c = "AUTO",
                                                         (1, -2, InAngFmt_c.F + 3),
                                                         fixFmtFromStringTolerant(IntAngFmtUpper_c));
    constant GainCorrCoefFmt_c : FixFormat_t   := choose(GainCorrCoefFmtUpper_c = "NONE",
                                                         FixFmt_Unused_c,
                                                         fixFmtFromStringTolerant(GainCorrCoefFmtUpper_c));
    constant Round_c           : FixRound_t    := cl_fix_round_from_string(Round_g);
    constant Saturate_c        : FixSaturate_t := cl_fix_saturate_from_string(Saturate_g);

    -- Constants
    constant AngleTableReal_c : RealArray_t(0 to 31) := (0.125,                 0.0737918088252,    0.0389895651887,    0.0197917120803,
                                                         0.00993426215277,    0.00497197391179,    0.00248659363948,    0.00124337269683,
                                                         0.000621695834357,    0.000310849102962,    0.000155424699705,    7.77123683806e-05,
                                                         3.88561865063e-05,    1.94280935426e-05,    9.71404680751e-06,    4.85702340828e-06,
                                                         2.4285117047e-06,    1.21425585242e-06,    6.0712792622e-07,    3.03563963111e-07,
                                                         1.51781981556e-07,    7.58909907779e-08,    3.7945495389e-08,    1.89727476945e-08,
                                                         9.48637384724e-09,    4.74318692362e-09,    2.37159346181e-09,    1.1857967309e-09,
                                                         5.92898365452e-10,    2.96449182726e-10,    1.48224591363e-10,    7.41122956816e-11);
    type AngleTable_t is array (0 to Iterations_g-1) of std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0);

    function angleTableStdlv return AngleTable_t is
        variable Table_v : AngleTable_t;
    begin

        for i in 0 to Iterations_g-1 loop
            Table_v(i) := cl_fix_from_real(AngleTableReal_c(i), IntAngFmt_c);
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

    constant GcCoef_c  : std_logic_vector(cl_fix_width(GainCorrCoefFmt_c)-1 downto 0) := cl_fix_from_real(1.0/cordicGain(Iterations_g), GainCorrCoefFmt_c);
    constant QuadFmt_c : FixFormat_t                                                  := (0, 0, 2);

    -- *** Functions ***
    -- Cordic step for X
    function cordicStepx (
        xLast        : std_logic_vector;
        yLast        : std_logic_vector;
        zLast        : std_logic_vector;
        shift        : integer) return std_logic_vector is
        -- Declarations
        constant YShifted_c : std_logic_vector := cl_fix_shift(yLast, IntXyFmt_c, -shift, IntXyFmt_c, Trunc_s, None_s);
    begin

        if signed(zLast) > 0 then
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
        xLast        : std_logic_vector;
        yLast        : std_logic_vector;
        zLast        : std_logic_vector;
        shift        : integer) return std_logic_vector is
        -- Declarations
        constant XShifted_c : std_logic_vector := cl_fix_shift(xLast, IntXyFmt_c, -shift, IntXyFmt_c, Trunc_s, None_s);
    begin

        if signed(zLast) > 0 then
            return    cl_fix_add(yLast, IntXyFmt_c,
                                XShifted_c, IntXyFmt_c,
                                IntXyFmt_c, Trunc_s, None_s);
        else
            return    cl_fix_sub(yLast, IntXyFmt_c,
                                XShifted_c, IntXyFmt_c,
                                IntXyFmt_c, Trunc_s, None_s);
        end if;
    end function;

    -- Cordic step for Z
    function cordicStepz (
        zLast        : std_logic_vector;
        iteration    : integer) return std_logic_vector is
        -- Declarations
        constant Atan_c : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0) := AngleTable_c(iteration);
    begin
        if signed(zLast) > 0 then
            return    cl_fix_sub(zLast, IntAngFmt_c,
                                Atan_c, IntAngFmt_c,
                                IntAngFmt_c, Trunc_s, None_s);
        else
            return    cl_fix_add(zLast, IntAngFmt_c,
                                Atan_c, IntAngFmt_c,
                                IntAngFmt_c, Trunc_s, None_s);
        end if;
    end function;

    -- Types
    type IntArr_t is array (natural range <>) of std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
    type AngArr_t is array (natural range <>) of std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0);

    -- Gain Correction Signals
    signal YQc, XQc   : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
    signal QcVld      : std_logic;
    signal In_Ready_I : std_logic;
    signal ProcMag    : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
    signal ProcValid  : std_logic;
    signal ProcAng    : std_logic_vector(cl_fix_width(InAngFmt_c)-1 downto 0);

begin

    -- *** Assertions ***
    assert InMagFmt_c.S = 0
        report "###ERROR###: olo_fix_cordic_rot: InMagFmt_g must be unsigned"
        severity error;
    assert InAngFmt_c.S = 0
        report "###ERROR###: olo_fix_cordic_rot: InAngFmt_g must be (0,0,x))"
        severity error;
    assert InAngFmt_c.I = 0
        report "###ERROR###: olo_fix_cordic_rot: InAngFmt_g must be (0,0,x))"
        severity error;
    assert IntXyFmt_c.S = 1
        report "###ERROR###: olo_fix_cordic_rot: IntXyFmt_g must be signed"
        severity error;
    assert IntAngFmt_c.S = 1
        report "###ERROR###: olo_fix_cordic_rot: IntAngFmt_g must be sig(1,-2,x)ned"
        severity error;
    assert IntAngFmt_c.I = -2
        report "###ERROR###: olo_fix_cordic_rot: IntAngFmt_g must be (1,-2,x)"
        severity error;
    assert Iterations_g <= 32
        report "###ERROR###: olo_fix_cordic_rot: Iterations_g must be <= 32"
        severity error;
    assert ModeUpper_c = "PIPELINED" or ModeUpper_c = "SERIAL"
        report "###ERROR###: olo_fix_cordic_rot: Mode_g must be PIPELINED or SERIAL"
        severity error;

    -- *** Pipelined Implementation ***
    g_pipelined : if ModeUpper_c = "PIPELINED" generate
        signal X, Y : IntArr_t(0 to Iterations_g);
        signal Z    : AngArr_t(0 to Iterations_g);
        signal Vld  : std_logic_vector(0 to Iterations_g);
        signal Quad : StlvArray2_t(0 to Iterations_g);
    begin
        -- Pipelined implementation can take a sample every clock cycle
        In_Ready_I <= '1';

        -- Implementation
        p_cordic_pipelined : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Initialization
                X(0)    <= ProcMag;
                Y(0)    <= (others => '0');
                Z(0)    <= cl_fix_resize(ProcAng, InAngFmt_c, IntAngFmt_c, Trunc_s, None_s);
                Quad(0) <= cl_fix_resize(ProcAng, InAngFmt_c, QuadFmt_c, Trunc_s, None_s);
                Vld(0)  <= ProcValid;

                -- Cordic Iterations_g
                Vld(1 to Vld'high)   <= Vld(0 to Vld'high-1);
                Quad(1 to Quad'high) <= Quad(0 to Quad'high-1);

                for i in 0 to Iterations_g-1 loop
                    X(i+1) <= cordicStepx(X(i), Y(i), Z(i), i);
                    Y(i+1) <= cordicStepy(X(i), Y(i), Z(i), i);
                    Z(i+1) <= cordicStepz(Z(i), i);
                end loop;

                -- Quadrant Correction
                QcVld <= Vld(Iterations_g);
                if (Quad(Iterations_g) = "00") or (Quad(Iterations_g) = "11") then
                    YQc <= Y(Iterations_g);
                    XQc <= X(Iterations_g);
                else
                    YQc <= cl_fix_neg(Y(Iterations_g), IntXyFmt_c, IntXyFmt_c, Trunc_s, None_s);
                    XQc <= cl_fix_neg(X(Iterations_g), IntXyFmt_c, IntXyFmt_c, Trunc_s, None_s);
                end if;

                if Rst = '1' then
                    Vld   <= (others => '0');
                    QcVld <= '0';
                end if;
            end if;
        end process;

    end generate;

    -- *** Serial Implementation ***
    g_serial : if ModeUpper_c = "SERIAL" generate
        signal Xin, Yin  : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
        signal Zin       : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0);
        signal XIn_Valid : std_logic;
        signal Quadin    : std_logic_vector(1 downto 0);
        signal X, Y      : std_logic_vector(cl_fix_width(IntXyFmt_c)-1 downto 0);
        signal Z         : std_logic_vector(cl_fix_width(IntAngFmt_c)-1 downto 0);
        signal CordVld   : std_logic;
        signal IterCnt   : integer range 0 to Iterations_g-1;
        signal Quad      : std_logic_vector(1 downto 0);
    begin

        p_cordic_serial : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- In Ready Handling
                if In_Ready_I = '1' and In_Valid = '1' then
                    In_Ready_I <= '0';
                end if;
                -- Assert ready depending on the latency of the input logic
                if (IterCnt = 2 and GainCorrCoefFmtUpper_c /= "NONE")  or
                   (IterCnt = 1 and GainCorrCoefFmtUpper_c = "NONE") then
                    In_Ready_I <= '1';
                end if;

                -- Input latching
                if XIn_Valid = '0' and ProcValid = '1' then
                    XIn_Valid <= '1';
                    Xin       <= ProcMag;
                    Yin       <= (others => '0');
                    Zin       <= cl_fix_resize(ProcAng, InAngFmt_c, IntAngFmt_c, Trunc_s, None_s);
                    Quadin    <= cl_fix_resize(ProcAng, InAngFmt_c, QuadFmt_c, Trunc_s, None_s);
                end if;

                -- CORDIC loop
                CordVld <= '0';
                if IterCnt = 0 then
                    -- start of calculation
                    if XIn_Valid = '1' then
                        X         <= cordicStepx(Xin, Yin, Zin, 0);
                        Y         <= cordicStepy(Xin, Yin, Zin, 0);
                        Quad      <= Quadin;
                        Z         <= cordicStepz(Zin, 0);
                        IterCnt   <= IterCnt+1;
                        XIn_Valid <= '0';
                    end if;
                else
                    -- Normal Calculation Step
                    X <= cordicStepx(X, Y, Z, IterCnt);
                    Y <= cordicStepy(X, Y, Z, IterCnt);
                    Z <= cordicStepz(Z, IterCnt);

                    if IterCnt = Iterations_g-1 then
                        IterCnt <= 0;
                        CordVld <= '1';
                    else
                        IterCnt <= IterCnt+1;
                    end if;
                end if;

                -- Quadrant Correction
                QcVld <= CordVld;
                if (Quad = "00") or (Quad = "11") then
                    YQc <= Y;
                    XQc <= X;
                else
                    YQc <= cl_fix_neg(Y, IntXyFmt_c, IntXyFmt_c, Trunc_s, None_s);
                    XQc <= cl_fix_neg(X, IntXyFmt_c, IntXyFmt_c, Trunc_s, None_s);
                end if;

                -- Reset
                if Rst = '1' then
                    XIn_Valid  <= '0';
                    IterCnt    <= 0;
                    CordVld    <= '0';
                    QcVld      <= '0';
                    In_Ready_I <= '1';
                end if;
            end if;
        end process;

    end generate;

    In_Ready <= In_Ready_I;

    -- *** Gain Correction and Input registers***
    -- Compensation Enabled
    g_gain_comp : if GainCorrCoefFmtUpper_c /= "NONE" generate
        signal In_Mag_Reg   : std_logic_vector(cl_fix_width(InMagFmt_c)-1 downto 0);
        signal In_Ang_Reg   : std_logic_vector(cl_fix_width(InAngFmt_c)-1 downto 0);
        signal In_Valid_Reg : std_logic;
    begin

        p_registers : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Input Regiseter
                In_Mag_Reg   <= In_Mag;
                In_Ang_Reg   <= In_Ang;
                In_Valid_Reg <= In_Ready_I and In_Valid;

                -- Compensate multiplier latency
                ProcAng <= In_Ang_Reg;

                -- Reset
                if Rst = '1' then
                    In_Valid_Reg <= '0';
                end if;
            end if;
        end process;

        i_mult_i : entity work.olo_fix_mult
            generic map (
                AFmt_g      => to_string(InMagFmt_c),
                BFmt_g      => to_string(GainCorrCoefFmt_c),
                ResultFmt_g => to_string(IntXyFmt_c),
                Round_g     => FixRound_Trunc_c,
                Saturate_g  => FixSaturate_None_c,
                OpRegs_g    => 1,
                RoundReg_g  => "NO",
                SatReg_g    => "NO"
            )
            port map (
                Clk         => Clk,
                Rst         => Rst,
                In_Valid    => In_Valid_Reg,
                In_A        => In_Mag_Reg,
                In_B        => GcCoef_c,
                Out_Valid   => ProcValid,
                Out_Result  => ProcMag
            );

    end generate;

    -- Compensation EnablDisabled
    g_no_gain_comp : if GainCorrCoefFmtUpper_c = "NONE" generate
        signal In_Mag_Reg   : std_logic_vector(cl_fix_width(InMagFmt_c)-1 downto 0);
        signal In_Ang_Reg   : std_logic_vector(cl_fix_width(InAngFmt_c)-1 downto 0);
        signal In_Valid_Reg : std_logic;
    begin

        p_registers : process (Clk) is
        begin
            if rising_edge(Clk) then
                -- Input Regiseter
                In_Mag_Reg   <= In_Mag;
                In_Ang_Reg   <= In_Ang;
                In_Valid_Reg <= In_Ready_I and In_Valid;

                -- Reset
                if Rst = '1' then
                    In_Valid_Reg <= '0';
                end if;
            end if;
        end process;

        -- Directly assign inputs (register is in main cordic process)
        ProcAng   <= In_Ang_Reg;
        ProcMag   <= cl_fix_resize(In_Mag_Reg, InMagFmt_c, IntXyFmt_c, Trunc_s, None_s);
        ProcValid <= In_Valid_Reg;

    end generate;

    -- *** Output Conditioning ***
    i_resize_i : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(IntXyFmt_c),
            ResultFmt_g => to_string(OutFmt_c),
            Round_g     => to_string(Round_c),
            Saturate_g  => to_string(Saturate_c),
            RoundReg_g  => choose(Round_c = Trunc_s, "NO", "YES"),
            SatReg_g    => choose(Saturate_c = None_s, "NO", "YES")
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => QcVld,
            In_A        => XQc,
            Out_Valid   => Out_Valid,
            Out_Result  => Out_I
        );

    i_resize_q : entity work.olo_fix_resize
        generic map (
            AFmt_g      => to_string(IntXyFmt_c),
            ResultFmt_g => to_string(OutFmt_c),
            Round_g     => to_string(Round_c),
            Saturate_g  => to_string(Saturate_c),
            RoundReg_g  => choose(Round_c = Trunc_s, "NO", "YES"),
            SatReg_g    => choose(Saturate_c = None_s, "NO", "YES")
        )
        port map (
            Clk         => Clk,
            Rst         => Rst,
            In_Valid    => QcVld,
            In_A        => YQc,
            Out_Result  => Out_Q
        );

end architecture;





