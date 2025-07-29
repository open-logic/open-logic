---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This entity implements reads a olo_fix signal from a file and applies it to a DUT. It is used
-- for writing testbenches for entities based on olo_fix.
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/fix/olo_fix_sim_stimuli.md
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
    use ieee.std_logic_textio.all;
    use ieee.math_real.all;

library work;
    use work.en_cl_fix_pkg.all;
    use work.olo_fix_pkg.all;

---------------------------------------------------------------------------------------------------
-- Entity Declaration
---------------------------------------------------------------------------------------------------
entity olo_fix_sim_stimuli is
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
        Rst      : in    std_logic;
        Ready    : in    std_logic := '1';
        Valid    : inout std_logic; -- input for slave, output for master
        Data     : out   std_logic_vector(fixFmtWidthFromString(Fmt_g)-1 downto 0)
    );
end entity;

architecture sim of olo_fix_sim_stimuli is

    -- constants
    constant Fmt_c : FixFormat_t := cl_fix_format_from_string(Fmt_g);

begin

    -- Main Process
    p_main : process is
        -- File
        file DataFile : text;

        -- Variables
        variable Line_v        : line;
        variable Fmt_v         : FixFormat_t;
        variable DataSlv_v     : std_logic_vector(cl_fix_width(Fmt_c)-1 downto 0);
        variable Good_v        : boolean;
        variable StallRandom_v : real;
        variable StallCycles_v : positive;
        variable Seed1_v       : positive := 1;
        variable Seed2_v       : positive := 1;
    begin

        -- Initialize
        if IsTimingMaster_g then
            Valid <= '0';
        else
            Valid <= 'Z';
        end if;
        Data <= (others => 'U');

        -- Waiit for reset release
        wait until rising_edge(Clk) and Rst = '0';

        -- Open file and check format
        file_open(DataFile, FilePath_g, read_mode);

        -- Check format (first line)
        readline(DataFile, Line_v);
        Fmt_v := cl_fix_format_from_string(Line_v.all);
        assert Fmt_v = Fmt_c
            report " olo_fix_sim_stimuli - Format mismatch: expected " & to_string(Fmt_c) &
                   ", got " & to_string(Fmt_v) & " in file " & FilePath_g
            severity error;

        -- Iterate through lines in file
        while not endfile(DataFile) loop
            -- Read line
            readline(DataFile, Line_v);
            hread(Line_v, DataSlv_v, Good_v);
            assert Good_v
                report " olo_fix_sim_stimuli - Failed to read from file" & FilePath_g
                severity error;

            -- Apply Data
            Data <= DataSlv_v;

            -- Wait for Ready signal if timing master
            if IsTimingMaster_g then
                -- Apply
                Valid <= '1';
                wait until rising_edge(Clk) and Ready = '1';
                -- Stall
                uniform(Seed1_v, Seed2_v, StallRandom_v);
                if StallRandom_v < StallProbability_g then
                    -- Remove Data
                    Valid <= '0';
                    Data  <= (others => 'U');

                    -- Wait for stall
                    uniform(Seed1_v, Seed2_v, StallRandom_v);
                    StallCycles_v := StallMinCycles_g + integer(StallRandom_v * (real(StallMaxCycles_g) - real(StallMinCycles_g)));

                    for i in 0 to StallCycles_v - 1 loop
                        wait until rising_edge(Clk);
                    end loop;

                end if;
            else
                wait until rising_edge(Clk) and Ready = '1' and Valid = '1';
            end if;
        end loop;

        -- Close the file
        file_close(DataFile);

        -- Idle output
        if IsTimingMaster_g then
            Valid <= '0';
        end if;
        Data <= (others => 'U');

        -- Done
        wait;

    end process;

end architecture;
