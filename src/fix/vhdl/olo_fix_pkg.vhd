---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025-2026 by Oliver Bruendler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing functions related to Open Logic fixed point mathematics.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_fix_pkg.md
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
    use ieee.std_logic_textio.all;

library std;
    use std.textio.all;

library work;
    use work.en_cl_fix_pkg.all;
    use work.en_cl_fix_private_pkg.all;
    use work.olo_base_pkg_string.all;
    use work.olo_base_pkg_math.all;
    use work.olo_base_pkg_array.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_fix_pkg is

    -- String Constants
    constant FixRound_Trunc_c     : string := "Trunc_s";
    constant FixRound_NonSymPos_c : string := "NonSymPos_s";
    constant FixRound_NonSymNeg_c : string := "NonSymNeg_s";
    constant FixRound_SymInf_c    : string := "SymInf_s";
    constant FixRound_SymZero_c   : string := "SymZero_s";
    constant FixRound_ConvEven_c  : string := "ConvEven_s";
    constant FixRound_ConvOdd_c   : string := "ConvOdd_s";

    constant FixSaturate_None_c    : string := "None_s";
    constant FixSaturate_Warn_c    : string := "Warn_s";
    constant FixSaturate_Sat_c     : string := "Sat_s";
    constant FixSaturate_SatWarn_c : string := "SatWarn_s";

    constant FixFmt_Unused_c : FixFormat_t := (0, 1, 0); -- Unused formats must have one bit to avoid issues

    -- Functions
    function fixFmtWidthFromString (fmt : string) return natural;
    function fixFmtWidthFromStringTolerant (fmt : string) return natural;

    -- Register is required if:
    -- - logic is present and regMode is "AUTO"
    -- - regMode is "YES"
    -- Meant for internal use only
    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean;

    -- Return fixed-point format from string and tolerate wrong strings (returning 0,0,0)
    function fixFmtFromStringTolerant (fmt : string) return FixFormat_t;

    -- Dynamic shifting function
    -- Required because synthesis tools do not accept variable shifts the way cl_fix_shift is writtin.
    function fixDynShift (
        a        : std_logic_vector;
        aFmt     : FixFormat_t;
        shift    : integer;
        minShift : integer       := 0;
        maxShift : integer;
        rFmt     : FixFormat_t;
        rnd      : FixRound_t    := Trunc_s;
        sat      : FixSaturate_t := None_s) return std_logic_vector;

    -- OLO Fix stimuli file reading functions
    -- The file format matches the one written by olo_fix_cosim (Python)

    -- Check the header (first line) of a fixed-point stimuli file against the expected format.
    procedure fixFileCheckHeader (
        file f : text;
        fmt    : FixFormat_t);

    -- Read a single sample (one data line) from a fixed-point stimuli file.
    -- The sample is returned as std_logic_vector with exactly cl_fix_width(fmt) bits.
    impure function fixFileReadSample (
        file f : text;
        fmt    : FixFormat_t) return std_logic_vector;

    -- Read a complete fixed-point stimuli file (given by its path) and return all samples as
    -- real values. The file header is checked against the passed format.
    impure function fixFileReadReal (
        filePath : string;
        fmt      : FixFormat_t) return RealArray_t;

    -- Read a complete fixed-point stimuli file (given by its path) and return all samples as a
    -- comma-separated string of real values (e.g. "0.1, 1.0e2"). The header is checked against fmt.
    impure function fixFileReadString (
        filePath : string;
        fmt      : FixFormat_t) return string;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_fix_pkg is

    function fixFmtWidthFromString (fmt : string) return natural is
        constant FixFmt_c : FixFormat_t := cl_fix_format_from_string(fmt);
    begin
        return cl_fix_width(FixFmt_c);
    end function;

    function fixFmtWidthFromStringTolerant (fmt : string) return natural is
        constant FixFmt_c : FixFormat_t := fixFmtFromStringTolerant(fmt);
    begin
        return cl_fix_width(FixFmt_c);
    end function;

    function fixImplementReg (
        logicPresent : boolean;
        regMode      : string) return boolean is
        variable Result_v : boolean := false;
    begin

        -- Calculate register requirement
        if compareNoCase(regMode, "yes") then
            Result_v := true;
        elsif compareNoCase(regMode, "no") then
            Result_v := false;
        elsif compareNoCase(regMode, "auto") then
            Result_v := logicPresent;
        -- coverage off
        -- unreachable
        else
            -- synthesis translate_off
            assert false
                report errorMessage("olo_fix_pkg.fixImplementReg()", "Invalid register mode '" & regMode & "' - must be YES, NO or AUTO")
                severity failure;
            -- synthesis translate_on
            -- coverage on
        end if;

        return Result_v;

    end function;

    function fixFmtFromStringTolerant (fmt : string) return FixFormat_t is
        type State_t is (BracketOpen_s, IntBits_s, FracBits_s, BracketClose_s, Done_s);

        variable Result_v : FixFormat_t := FixFmt_Unused_c;
        variable State_v  : State_t     := BracketOpen_s;
    begin

        for i in fmt'low to fmt'high loop

            case State_v is
                when BracketOpen_s =>
                    if fmt(i) = '(' then
                        State_v := IntBits_s;
                    end if;
                when IntBits_s =>
                    if fmt(i) = ',' then
                        State_v := FracBits_s;
                    end if;
                when FracBits_s =>
                    if fmt(i) = ',' then
                        State_v := BracketClose_s;
                    end if;
                when BracketClose_s =>
                    if fmt(i) = ')' then
                        State_v := Done_s;
                    end if;
                when Done_s =>
                    null; -- unreachable
                -- coverage off
                when others =>
                    null; -- unreachable
                -- coverage on
            end case;

        end loop;

        if State_v = Done_s then
            Result_v := cl_fix_format_from_string(fmt);
        end if;

        return Result_v;
    end function;

    function fixDynShift (
        a        : std_logic_vector;
        aFmt     : FixFormat_t;
        shift    : integer;
        minShift : integer       := 0;
        maxShift : integer;
        rFmt     : FixFormat_t;
        rnd      : FixRound_t    := Trunc_s;
        sat      : FixSaturate_t := None_s) return std_logic_vector is
        -- Local declaratoins
        constant FullFmt_c : FixFormat_t := (max(aFmt.S, rFmt.S), max(aFmt.I+maxShift, rFmt.I), max(aFmt.F-minShift, rFmt.F+1)); -- Additional bit for rounding
        variable FullA_v   : std_logic_vector(cl_fix_width(FullFmt_c)-1 downto 0);
        variable FullOut_v : std_logic_vector(FullA_v'range);
    begin
        -- assertions
        -- synthesis translate_off
        assert shift >= minShift
            report errorMessage("olo_fix_pkg.fixDynShift()", "Shift must be >= minShift")
            severity error;
        assert shift <= maxShift
            report errorMessage("olo_fix_pkg.fixDynShift()", "Shift must be <= maxShift")
            severity error;
        -- synthesis translate_on

        -- Implementation
        FullA_v := cl_fix_resize(a, aFmt, FullFmt_c);

        for i in minShift to maxShift loop -- make a loop to ensure the shift is a constant (required by the tools)
            if i = shift then
                FullOut_v := cl_fix_shift(FullA_v, FullFmt_c, i, FullFmt_c, Trunc_s, None_s);
            end if;
        end loop;

        return cl_fix_resize(FullOut_v, FullFmt_c, rFmt, rnd, sat);
    end function;

    procedure fixFileCheckHeader (
        file f : text;
        fmt    : FixFormat_t) is
        variable Line_v : line;
        variable Fmt_v  : FixFormat_t;
    begin
        readline(f, Line_v);
        Fmt_v := cl_fix_format_from_string(trim(Line_v.all));
        assert Fmt_v = fmt
            report errorMessage("olo_fix_pkg.fixFileCheckHeader()", "Format mismatch - expected " & to_string(fmt) &
                   ", got " & to_string(Fmt_v))
            severity error;
    end procedure;

    impure function fixFileReadSample (
        file f : text;
        fmt    : FixFormat_t) return std_logic_vector is
        constant Width_c   : natural := cl_fix_width(fmt);
        constant NibbleW_c : natural := 4 * ((Width_c + 3) / 4); -- width rounded up to the next nibble
        variable Line_v    : line;
        variable Raw_v     : std_logic_vector(NibbleW_c - 1 downto 0);
        variable Good_v    : boolean;
    begin
        -- The sample is stored as hex (one nibble per digit), so read into a nibble-aligned vector
        readline(f, Line_v);
        hread(Line_v, Raw_v, Good_v);
        assert Good_v
            report errorMessage("olo_fix_pkg.fixFileReadSample()", "Failed to read sample from file")
            severity error;

        -- Return exactly the format width
        return Raw_v(Width_c - 1 downto 0);
    end function;

    -- Count the number of data lines (samples) in a file, excluding the format header
    impure function fixFileCountSamples (filePath : string) return natural is
        file DataFile : text;

        variable Line_v  : line;
        variable Count_v : natural := 0;
    begin
        file_open(DataFile, filePath, read_mode);
        readline(DataFile, Line_v); -- skip header

        while not endfile(DataFile) loop
            readline(DataFile, Line_v);
            Count_v := Count_v + 1;
        end loop;

        file_close(DataFile);
        return Count_v;
    end function;

    impure function fixFileReadReal (
        filePath : string;
        fmt      : FixFormat_t) return RealArray_t is
        constant Count_c : natural := fixFileCountSamples(filePath);

        file DataFile : text;

        variable Result_v : RealArray_t(0 to Count_c - 1);
    begin
        -- Open file and check header against the passed format
        file_open(DataFile, filePath, read_mode);
        fixFileCheckHeader(DataFile, fmt);

        -- Read all samples and convert to real
        for i in Result_v'range loop
            Result_v(i) := cl_fix_to_real(fixFileReadSample(DataFile, fmt), fmt);
        end loop;

        file_close(DataFile);
        return Result_v;
    end function;

    impure function fixFileReadString (
        filePath : string;
        fmt      : FixFormat_t) return string is
        constant Values_c : RealArray_t := fixFileReadReal(filePath, fmt);
        variable Line_v   : line;
    begin
        -- Empty file -> empty string
        if Values_c'length = 0 then
            return "";
        end if;

        -- Build the comma-separated list of real values
        for i in Values_c'range loop
            if i /= Values_c'low then
                write(Line_v, string'(", "));
            end if;
            write(Line_v, real'image(Values_c(i)));
        end loop;

        return Line_v.all;
    end function;

end package body;
