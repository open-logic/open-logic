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

library vunit_lib;
    context vunit_lib.vunit_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_ft_ecc_encode_tb is
    generic (
        runner_cfg : string;
        Width_g    : positive range 5 to 128 := 32;
        Pipeline_g : natural  range 0 to 2   := 0
    );
end entity;

architecture sim of olo_ft_ecc_encode_tb is

    constant ClkPeriod_c     : time     := 10 ns;
    constant CodewordWidth_c : positive := eccCodewordWidth(Width_g);

    signal Clk          : std_logic := '0';
    signal In_Data      : std_logic_vector(Width_g - 1 downto 0)         := (others => '0');
    signal In_BitFlip   : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');
    signal Out_Codeword : std_logic_vector(CodewordWidth_c - 1 downto 0);

    constant NoFlip_c : std_logic_vector(CodewordWidth_c - 1 downto 0) := (others => '0');

begin

    Clk <= not Clk after 0.5 * ClkPeriod_c;

    i_dut : entity olo.olo_ft_ecc_encode
        generic map (
            Width_g    => Width_g,
            Pipeline_g => Pipeline_g
        )
        port map (
            Clk          => Clk,
            In_Data      => In_Data,
            In_BitFlip   => In_BitFlip,
            Out_Codeword => Out_Codeword
        );

    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable Expected_v : std_logic_vector(CodewordWidth_c - 1 downto 0);

        procedure applyAndCheck (
            constant Data_v    : std_logic_vector;
            constant Flip_v    : std_logic_vector;
            constant Message_c : string) is
        begin
            wait until rising_edge(Clk);
            In_Data    <= Data_v;
            In_BitFlip <= Flip_v;
            Expected_v := eccEncode(Data_v) xor Flip_v;

            wait until rising_edge(Clk);
            for i in 1 to Pipeline_g loop
                wait until rising_edge(Clk);
            end loop;
            wait for 1 ns;

            check_equal(Out_Codeword, Expected_v, Message_c);
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);

        wait for 1 ns;

        while test_suite loop

            if run("Encode-NoFlip") then
                applyAndCheck(toUslv(0,    Width_g),         NoFlip_c, "data=0");
                applyAndCheck(toUslv(16#5A#, Width_g),       NoFlip_c, "data=5A");
                applyAndCheck((Width_g - 1 downto 0 => '1'), NoFlip_c, "data=allOnes");

            elsif run("Encode-WithSingleFlip") then
                for i in 0 to CodewordWidth_c - 1 loop
                    applyAndCheck(toUslv(16#A5#, Width_g), setBits(i, CodewordWidth_c),
                        "single flip at " & integer'image(i));
                end loop;

            elsif run("Encode-WithDoubleFlip") then
                applyAndCheck(toUslv(16#5A#, Width_g), setBits(0, 1, CodewordWidth_c),                                       "(0,1)");
                applyAndCheck(toUslv(16#5A#, Width_g), setBits(0, CodewordWidth_c - 1, CodewordWidth_c),                     "(0,N-1)");
                applyAndCheck(toUslv(16#5A#, Width_g), setBits(1, 2, CodewordWidth_c),                                       "(1,2)");
                applyAndCheck(toUslv(16#5A#, Width_g), setBits(2, 5, CodewordWidth_c),                                       "(2,5)");
                applyAndCheck(toUslv(16#5A#, Width_g), setBits(CodewordWidth_c / 2, CodewordWidth_c / 2 + 1, CodewordWidth_c), "(mid,mid+1)");

            end if;

        end loop;

        wait for 1 ns;
        test_runner_cleanup(runner);
    end process;

end architecture;
