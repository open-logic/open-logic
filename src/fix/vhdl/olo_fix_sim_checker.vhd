----------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements reads a olo_fix signal from a file and checks DUT outputs against it. It is used
-- for writing testbenches for entities based on olo_fix.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_sim_checker.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use std.textio.all;
    use ieee.math_real.all;

library work;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;
    use work.olo_base_pkg_string.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_sim_checker is
    generic (
        FilePath_g         : string;
        IsTimingMaster_g   : boolean  := true;
        Fmt_g              : string;
        StallProbability_g : real     := 0.0;
        StallMaxCycles_g   : positive := 1;
        StallMinCycles_g   : positive := 1
    );
    port (
        Clk      : in    std_logic;
        Ready    : inout std_logic; -- input for slave, output for master
        Valid    : in    std_logic;
        Data     : in    std_logic_vector(fixFmtWidthFromString(Fmt_g)-1 downto 0)
    );
end entity;

architecture sim of olo_fix_sim_checker is

    -- constants
    constant Fmt_c        : FixFormat_t := cl_fix_format_from_string(Fmt_g);
    constant EntityName_c : string      := "olo_fix_sim_checker";

begin

    -- Main Process
    p_main : process is
        -- File
        file DataFile : text;

        -- Variables
        variable DataSlv_v     : std_logic_vector(cl_fix_width(Fmt_c)-1 downto 0);
        variable StallRandom_v : real;
        variable StallCycles_v : positive;
        variable Seed1_v       : positive := 1;
        variable Seed2_v       : positive := 1;
        variable LineNumber_v  : positive;
    begin

        -- Initialize
        if IsTimingMaster_g then
            Ready <= '0';
        else
            Ready <= 'Z';
        end if;

        -- Open file and check format (first line)
        file_open(DataFile, FilePath_g, read_mode);
        fixFileCheckHeader(DataFile, Fmt_c);
        LineNumber_v := 2;

        -- Iterate through lines in file
        while not endfile(DataFile) loop

            -- Wait for Ready signal if timing master
            if IsTimingMaster_g then
                -- Stall
                uniform(Seed1_v, Seed2_v, StallRandom_v);
                if StallRandom_v < StallProbability_g then
                    Ready <= '0';

                    -- Wait for stall
                    uniform(Seed1_v, Seed2_v, StallRandom_v);
                    StallCycles_v := StallMinCycles_g + integer(StallRandom_v * (real(StallMaxCycles_g) - real(StallMinCycles_g)));

                    for i in 0 to StallCycles_v - 1 loop
                        wait until rising_edge(Clk) and Valid = '1';
                    end loop;

                    wait until falling_edge(Clk);
                end if;
                Ready <= '1';
                wait until rising_edge(Clk) and Valid = '1';
            else
                wait until rising_edge(Clk) and Ready = '1' and Valid = '1';
            end if;

            -- Read line
            DataSlv_v := fixFileReadSample(DataFile, Fmt_c);

            -- Check Data
            -- Some tools have problems with to_string(). Because this is not needed for synthesis, I disable it.
            -- pragma translate_off
            assert Data = DataSlv_v
                report errorMessage(EntityName_c, "Data mismatch: expected " & to_string(DataSlv_v) &
                       ", got " & to_string(Data) & " - file " & FilePath_g &
                       " - line " & to_string(LineNumber_v))
                severity error;
            -- pragma translate_on
            LineNumber_v := LineNumber_v + 1;

        end loop;

        -- Close the file
        file_close(DataFile);

        -- Idle output
        if IsTimingMaster_g then
            Ready <= '0';
        end if;

        -- Done
        wait;

    end process;

end architecture;
