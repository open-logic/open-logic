---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_pkg_ecc_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture sim of olo_ft_pkg_ecc_tb is

    -- Encode `Data`, XOR `Flip` into the codeword, then decode and check the
    -- expected SEC/DED flags. When `CheckData` is true, also check that the
    -- decoded data matches `Data` (must hold for 0 or 1 bit-flip; not for 2).
    procedure checkEcc (
        constant Data        : in std_logic_vector;
        constant Flip        : in std_logic_vector;
        constant ExpectedSec : in std_logic;
        constant ExpectedDed : in std_logic;
        constant CheckData   : in boolean) is
        constant DataWidth_c : positive := Data'length;
        variable Codeword_v  : std_logic_vector(eccCodewordWidth(DataWidth_c) - 1 downto 0);
        variable SynPar_v    : std_logic_vector(eccParityBits(DataWidth_c) downto 0);
        variable Decoded_v   : std_logic_vector(DataWidth_c - 1 downto 0);
        variable Sec_v       : std_logic;
        variable Ded_v       : std_logic;
    begin
        Codeword_v := eccEncode(Data) xor Flip;
        SynPar_v   := eccSyndromeAndParity(Codeword_v, DataWidth_c);
        Decoded_v  := eccCorrectData(Codeword_v, SynPar_v, DataWidth_c);
        Sec_v      := eccSecError(SynPar_v);
        Ded_v      := eccDedError(SynPar_v);

        check_equal(Sec_v, ExpectedSec,
            "eccSecError mismatch (DataWidth=" & integer'image(DataWidth_c) & ")");
        check_equal(Ded_v, ExpectedDed,
            "eccDedError mismatch (DataWidth=" & integer'image(DataWidth_c) & ")");
        if CheckData then
            check_equal(Decoded_v, Data,
                "Decoded data mismatch (DataWidth=" & integer'image(DataWidth_c) & ")");
        end if;
    end procedure;

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 sec);

    p_control : process is
        variable Data8_v   : std_logic_vector(7 downto 0);
        variable Data16_v  : std_logic_vector(15 downto 0);
        variable Data32_v  : std_logic_vector(31 downto 0);
        variable Data64_v  : std_logic_vector(63 downto 0);
        variable Data128_v : std_logic_vector(127 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop

            if run("eccParityBits") then
                -- Hamming parity bits only (excludes the overall parity bit; total parity = Hamming + 1).
                check_equal(eccParityBits(8),   4, "eccParityBits(8)");
                check_equal(eccParityBits(16),  5, "eccParityBits(16)");
                check_equal(eccParityBits(32),  6, "eccParityBits(32)");
                check_equal(eccParityBits(64),  7, "eccParityBits(64)");
                check_equal(eccParityBits(128), 8, "eccParityBits(128)");

            elsif run("eccCodewordWidth") then
                check_equal(eccCodewordWidth(8),    13, "eccCodewordWidth(8)");
                check_equal(eccCodewordWidth(16),   22, "eccCodewordWidth(16)");
                check_equal(eccCodewordWidth(32),   39, "eccCodewordWidth(32)");
                check_equal(eccCodewordWidth(64),   72, "eccCodewordWidth(64)");
                check_equal(eccCodewordWidth(128), 137, "eccCodewordWidth(128)");

            elsif run("Roundtrip-NoError") then
                -- Encode then decode without error injection: SEC=0, DED=0, data preserved.
                Data8_v   := X"00";
                checkEcc(Data8_v, zerosVector(eccCodewordWidth(8)), '0', '0', true);
                Data8_v   := X"FF";
                checkEcc(Data8_v, zerosVector(eccCodewordWidth(8)), '0', '0', true);
                Data8_v   := X"5A";
                checkEcc(Data8_v, zerosVector(eccCodewordWidth(8)), '0', '0', true);
                Data16_v  := X"DEAD";
                checkEcc(Data16_v, zerosVector(eccCodewordWidth(16)), '0', '0', true);
                Data32_v  := X"DEADBEEF";
                checkEcc(Data32_v, zerosVector(eccCodewordWidth(32)), '0', '0', true);
                Data64_v  := X"0123456789ABCDEF";
                checkEcc(Data64_v, zerosVector(eccCodewordWidth(64)), '0', '0', true);
                Data128_v := X"0123456789ABCDEF_FEDCBA9876543210";
                checkEcc(Data128_v, zerosVector(eccCodewordWidth(128)), '0', '0', true);

            elsif run("SecAllBits-w8") then
                -- Flip every codeword bit individually: SEC must trigger and data must be corrected.
                Data8_v := X"5A";
                for i in 0 to eccCodewordWidth(8) - 1 loop
                    checkEcc(Data8_v, setBits(i, eccCodewordWidth(8)), '1', '0', true);
                end loop;

            elsif run("SecAllBits-w16") then
                Data16_v := X"A55A";
                for i in 0 to eccCodewordWidth(16) - 1 loop
                    checkEcc(Data16_v, setBits(i, eccCodewordWidth(16)), '1', '0', true);
                end loop;

            elsif run("SecAllBits-w32") then
                Data32_v := X"DEADBEEF";
                for i in 0 to eccCodewordWidth(32) - 1 loop
                    checkEcc(Data32_v, setBits(i, eccCodewordWidth(32)), '1', '0', true);
                end loop;

            elsif run("SecAllBits-w64") then
                Data64_v := X"0123456789ABCDEF";
                for i in 0 to eccCodewordWidth(64) - 1 loop
                    checkEcc(Data64_v, setBits(i, eccCodewordWidth(64)), '1', '0', true);
                end loop;

            elsif run("SecAllBits-w128") then
                Data128_v := X"0123456789ABCDEF_FEDCBA9876543210";
                for i in 0 to eccCodewordWidth(128) - 1 loop
                    checkEcc(Data128_v, setBits(i, eccCodewordWidth(128)), '1', '0', true);
                end loop;

            elsif run("DedAllPairs-w8") then
                -- Exhaustive at small width: 13-bit codeword, C(13,2)=78 pairs.
                -- Proves DED holds for every two-flip pattern at the package level.
                Data8_v := X"5A";
                for i in 0 to eccCodewordWidth(8) - 2 loop
                    for j in i + 1 to eccCodewordWidth(8) - 1 loop
                        checkEcc(Data8_v, setBits(i, j, eccCodewordWidth(8)), '0', '1', false);
                    end loop;
                end loop;

            elsif run("DedSampledPairs-w64") then
                -- Representative DED pairs: parity+parity, parity+data, far-apart, adjacent.
                Data64_v := X"0123456789ABCDEF";
                checkEcc(Data64_v, setBits(0, 1, eccCodewordWidth(64)), '0', '1', false);
                checkEcc(Data64_v, setBits(0, eccCodewordWidth(64) - 1, eccCodewordWidth(64)), '0', '1', false);
                checkEcc(Data64_v, setBits(1, 2, eccCodewordWidth(64)), '0', '1', false);
                checkEcc(Data64_v, setBits(2, 5, eccCodewordWidth(64)), '0', '1', false);
                checkEcc(Data64_v, setBits(eccCodewordWidth(64) / 2, eccCodewordWidth(64) / 2 + 1, eccCodewordWidth(64)), '0', '1', false);

            elsif run("DedSampledPairs-w128") then
                Data128_v := X"0123456789ABCDEF_FEDCBA9876543210";
                checkEcc(Data128_v, setBits(0, 1, eccCodewordWidth(128)), '0', '1', false);
                checkEcc(Data128_v, setBits(0, eccCodewordWidth(128) - 1, eccCodewordWidth(128)), '0', '1', false);
                checkEcc(Data128_v, setBits(1, 2, eccCodewordWidth(128)), '0', '1', false);
                checkEcc(Data128_v, setBits(2, 5, eccCodewordWidth(128)), '0', '1', false);
                checkEcc(Data128_v, setBits(eccCodewordWidth(128) / 2, eccCodewordWidth(128) / 2 + 1, eccCodewordWidth(128)), '0', '1', false);

            end if;

        end loop;

        wait for 1 ns;

        -- TB done
        test_runner_cleanup(runner);
    end process;

end architecture;
