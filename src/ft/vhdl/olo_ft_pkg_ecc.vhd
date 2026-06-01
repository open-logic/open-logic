---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package containing SECDED (Single Error Correction, Double Error Detection)
-- Hamming code functions for ECC-protected memories.
--
-- The encoding uses a standard Hamming code with an additional overall parity
-- bit for double error detection. Codeword layout:
--   Bit 0:               Overall parity (SECDED extension)
--   Bits 1..n:           Hamming codeword (data + parity interleaved)
--   Power-of-2 positions: Parity bits
--   Other positions:      Data bits

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_ft_pkg_ecc is

    -- Calculate number of Hamming parity bits needed (excluding overall parity)
    function eccParityBits (
        DataWidth : positive) return positive;

    -- Calculate total codeword width (data + Hamming parity + overall parity)
    function eccCodewordWidth (
        DataWidth : positive) return positive;

    -- Encode data into a SECDED codeword
    function eccEncode (
        Data : std_logic_vector) return std_logic_vector;

    -- Compute syndrome and overall parity from a codeword
    -- Result: bit ParityBits = overall parity error, bits ParityBits-1..0 = syndrome
    function eccSyndromeAndParity (
        Codeword  : std_logic_vector;
        DataWidth : positive) return std_logic_vector;

    -- Extract corrected data from a codeword using precomputed syndrome/parity
    function eccCorrectData (
        Codeword  : std_logic_vector;
        SynPar    : std_logic_vector;
        DataWidth : positive) return std_logic_vector;

    -- Return '1' if a single error was corrected (overall parity is odd)
    function eccSecError (
        SynPar : std_logic_vector) return std_logic;

    -- Return '1' if a double error was detected (syndrome nonzero, overall parity even)
    function eccDedError (
        SynPar : std_logic_vector) return std_logic;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_ft_pkg_ecc is

    -- Calculate number of Hamming parity bits needed (excluding overall parity)
    -- Finds smallest m such that 2^m >= DataWidth + m + 1
    function eccParityBits (
        DataWidth : positive) return positive is
        variable Bits_v : positive := 1;
    begin

        while 2**Bits_v < DataWidth + Bits_v + 1 loop
            Bits_v := Bits_v + 1;
        end loop;

        return Bits_v;
    end function;

    -- Calculate total codeword width
    function eccCodewordWidth (
        DataWidth : positive) return positive is
    begin
        -- data bits + Hamming parity bits + 1 overall parity bit
        return DataWidth + eccParityBits(DataWidth) + 1;
    end function;

    -- Encode data into a SECDED codeword
    function eccEncode (
        Data : std_logic_vector) return std_logic_vector is
        constant DataWidth_c   : positive                                     := Data'length;
        constant ParityBits_c  : positive                                     := eccParityBits(DataWidth_c);
        constant HammingLen_c  : positive                                     := DataWidth_c + ParityBits_c;
        constant CodewordLen_c : positive                                     := HammingLen_c + 1;
        variable Codeword_v    : std_logic_vector(CodewordLen_c - 1 downto 0) := (others => '0');
        variable DataNorm_v    : std_logic_vector(DataWidth_c - 1 downto 0);
        variable DataIdx_v     : natural                                      := 0;
        variable Parity_v      : std_logic;
    begin
        -- Normalize data to (width-1 downto 0)
        DataNorm_v := Data;

        -- Place data bits at non-power-of-2 Hamming positions (1-indexed)
        DataIdx_v := 0;

        for i in 1 to HammingLen_c loop
            if not isPower2(i) then
                Codeword_v(i) := DataNorm_v(DataIdx_v);
                DataIdx_v     := DataIdx_v + 1;
            end if;
        end loop;

        -- Calculate parity bits at power-of-2 positions
        for p in 0 to ParityBits_c - 1 loop
            Parity_v := '0';

            for i in 1 to HammingLen_c loop
                if (i / (2**p)) mod 2 = 1 then
                    Parity_v := Parity_v xor Codeword_v(i);
                end if;
            end loop;

            Codeword_v(2**p) := Parity_v;
        end loop;

        -- Calculate overall parity (XOR of all Hamming bits)
        Parity_v := '0';

        for i in 1 to HammingLen_c loop
            Parity_v := Parity_v xor Codeword_v(i);
        end loop;

        Codeword_v(0) := Parity_v;

        return Codeword_v;
    end function;

    -- Compute syndrome and overall parity from a codeword
    function eccSyndromeAndParity (
        Codeword  : std_logic_vector;
        DataWidth : positive) return std_logic_vector is
        constant ParityBits_c : positive                                    := eccParityBits(DataWidth);
        constant HammingLen_c : positive                                    := DataWidth + ParityBits_c;
        variable CwNorm_v     : std_logic_vector(HammingLen_c downto 0);
        variable Syndrome_v   : std_logic_vector(ParityBits_c - 1 downto 0) := (others => '0');
        variable OverallPar_v : std_logic                                   := '0';
        variable Result_v     : std_logic_vector(ParityBits_c downto 0);
    begin
        CwNorm_v := Codeword;

        -- Calculate syndrome bits
        for p in 0 to ParityBits_c - 1 loop

            for i in 1 to HammingLen_c loop
                if (i / (2**p)) mod 2 = 1 then
                    Syndrome_v(p) := Syndrome_v(p) xor CwNorm_v(i);
                end if;
            end loop;

        end loop;

        -- Calculate overall parity (XOR of all bits including position 0)
        for i in 0 to HammingLen_c loop
            OverallPar_v := OverallPar_v xor CwNorm_v(i);
        end loop;

        Result_v(ParityBits_c - 1 downto 0) := Syndrome_v;
        Result_v(ParityBits_c)              := OverallPar_v;
        return Result_v;
    end function;

    -- Extract corrected data from a codeword using precomputed syndrome/parity
    function eccCorrectData (
        Codeword  : std_logic_vector;
        SynPar    : std_logic_vector;
        DataWidth : positive) return std_logic_vector is
        constant ParityBits_c  : positive := eccParityBits(DataWidth);
        constant HammingLen_c  : positive := DataWidth + ParityBits_c;
        variable Syndrome_v    : natural;
        variable CwCorrected_v : std_logic_vector(HammingLen_c downto 0);
        variable Data_v        : std_logic_vector(DataWidth - 1 downto 0);
        variable DataIdx_v     : natural  := 0;
    begin
        Syndrome_v := to_integer(unsigned(SynPar(ParityBits_c - 1 downto 0)));

        -- Copy codeword
        CwCorrected_v := Codeword;

        -- Correct single-bit error when overall parity is odd and syndrome is valid
        if SynPar(SynPar'high) = '1' and Syndrome_v > 0 and Syndrome_v <= HammingLen_c then
            CwCorrected_v(Syndrome_v) := not CwCorrected_v(Syndrome_v);
        end if;

        -- Extract data bits from non-power-of-2 positions
        DataIdx_v := 0;

        for i in 1 to HammingLen_c loop
            if not isPower2(i) then
                Data_v(DataIdx_v) := CwCorrected_v(i);
                DataIdx_v         := DataIdx_v + 1;
            end if;
        end loop;

        return Data_v;
    end function;

    -- Return '1' if a single error was corrected
    -- Under SECDED assumption (at most 2 bit errors), odd overall parity = single error
    function eccSecError (
        SynPar : std_logic_vector) return std_logic is
    begin
        return SynPar(SynPar'high);
    end function;

    -- Return '1' if a double error was detected
    -- Syndrome nonzero with even overall parity = double error
    function eccDedError (
        SynPar : std_logic_vector) return std_logic is
        variable SynNonZero_v : std_logic := '0';
    begin

        -- SynPar layout: bits 0..high-1 = syndrome, bit 'high = overall parity error.
        -- OR-reduce only the syndrome bits; the overall-parity bit is intentionally excluded
        -- because it is what distinguishes SEC (overall='1') from DED (overall='0' & syndrome /= 0).
        for i in 0 to SynPar'high - 1 loop
            SynNonZero_v := SynNonZero_v or SynPar(i);
        end loop;

        return SynNonZero_v and not SynPar(SynPar'high);
    end function;

end package body;
