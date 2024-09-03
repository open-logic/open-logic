---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- This is a very basic clock crossing that allows to clock-cross resets. It
-- does assert reset on the other clock domain immediately and de-asserts the
-- reset synchronously to the corresponding clock.
-- The reset is clock-crossed in both directions

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_cc_reset is
    port (
        A_Clk       : in    std_logic;
        A_RstIn     : in    std_logic := '0';
        A_RstOut    : out   std_logic;
        B_Clk       : in    std_logic;
        B_RstIn     : in    std_logic := '0';
        B_RstOut    : out   std_logic
    );
end entity;

---------------------------------------------------------------------------------------------------
-- Architecture
---------------------------------------------------------------------------------------------------
architecture struct of olo_base_cc_reset is

    -- Domain A signals
    signal RstALatch  : std_logic := '1';
    signal RstRqstB2A : std_logic_vector(2 downto 0) := (others => '0');
    signal RstAckB2A  : std_logic; -- std_logic_vector(2 downto 0) := (others => '0');

    -- Domain B signals
    signal RstBLatch  : std_logic := '1';
    signal RstRqstA2B : std_logic_vector(2 downto 0) := (others => '0');
    signal RstAckA2B  : std_logic; -- std_logic_vector(2 downto 0) := (others => '0');

    -- Synthesis attributes AMD (Vivado)
    attribute SHREG_EXTRACT : string;
    attribute SHREG_EXTRACT of RstRqstB2A : signal is "no";
    attribute SHREG_EXTRACT of RstAckB2A  : signal is "no";
    attribute SHREG_EXTRACT of RstRqstA2B : signal is "no";
    attribute SHREG_EXTRACT of RstAckA2B  : signal is "no";

    -- Synthesis attributes AMD (Vivado) and Efinix (Efinity)
    attribute SYN_SRLSTYLE : string;
    attribute SYN_SRLSTYLE of RstRqstB2A : signal is "registers";
    attribute SYN_SRLSTYLE of RstAckB2A  : signal is "registers";
    attribute SYN_SRLSTYLE of RstRqstA2B : signal is "registers";
    attribute SYN_SRLSTYLE of RstAckA2B  : signal is "registers";

    attribute ASYNC_REG : boolean;
    attribute ASYNC_REG of RstRqstB2A : signal is true;
    attribute ASYNC_REG of RstAckB2A  : signal is true;
    attribute ASYNC_REG of RstRqstA2B : signal is true;
    attribute ASYNC_REG of RstAckA2B  : signal is true;

    -- Synthesis attributes Altera (Quartus)
    attribute DONT_MERGE : boolean;
    attribute DONT_MERGE of RstRqstB2A : signal is true;
    attribute DONT_MERGE of RstAckB2A  : signal is true;
    attribute DONT_MERGE of RstRqstA2B : signal is true;
    attribute DONT_MERGE of RstAckA2B  : signal is true;

    attribute PRESERVE : boolean;
    attribute PRESERVE of RstRqstB2A : signal is true;
    attribute PRESERVE of RstAckB2A  : signal is true;
    attribute PRESERVE of RstRqstA2B : signal is true;
    attribute PRESERVE of RstAckA2B  : signal is true;

begin

    -- Domain A
    ARstSync_p : process (A_Clk, RstBLatch) is
    begin
        if RstBLatch = '1' then
            RstRqstB2A <= (others => '1');
        elsif rising_edge(A_Clk) then
            RstRqstB2A <= RstRqstB2A(RstRqstB2A'left - 1 downto 0) & '0';
        end if;
    end process;

    ARst_p : process (A_Clk) is
    begin
        if rising_edge(A_Clk) then
            -- RstAckB2A <= RstAckB2A(RstAckB2A'left - 1 downto 0) & RstRqstA2B(RstRqstA2B'left);
            -- Latch reset when it occurs
            if A_RstIn = '1' then
                RstALatch <= '1';
            -- Remove reset only when reset of B side was asserted for at least one clock cycle
            elsif RstAckB2A = '1' then
                RstALatch <= '0';
            end if;
        end if;
    end process;

    A_RstOut <= RstALatch or RstRqstB2A(RstRqstB2A'left);

    -- Domain B
    BRstSync_p : process (B_Clk, RstALatch) is
    begin
        if RstALatch = '1' then
            RstRqstA2B <= (others => '1');
        elsif rising_edge(B_Clk) then
            RstRqstA2B <= RstRqstA2B(RstRqstA2B'left - 1 downto 0) & '0';
        end if;
    end process;

    BRst_p : process (B_Clk) is
    begin
        if rising_edge(B_Clk) then
            -- RstAckA2B <= RstAckA2B(RstAckA2B'left - 1 downto 0) & RstRqstB2A(RstRqstB2A'left);
            -- Latch reset when it occurs
            if B_RstIn = '1' then
                RstBLatch <= '1';
            -- Remove reset only when reset of B side was asserted for at least one clock cycle
            elsif RstAckA2B = '1' then
                RstBLatch <= '0';
            end if;
        end if;
    end process;

    B_RstOut <= RstBLatch or RstRqstA2B(RstRqstA2B'left);

    -- Ack Crossing
    i_ackb2a : entity work.olo_base_cc_bits
        generic map (
            Width_g => 1
        )
        port map (
            -- Input clock domain
            In_Clk      => B_Clk,
            In_Rst      => '0',
            In_Data(0)  => RstRqstA2B(RstRqstA2B'left),
            -- Output clock domain
            Out_Clk     => A_Clk,
            Out_Rst     => '0',
            Out_Data(0) => RstAckB2A
        );
    i_acka2b : entity work.olo_base_cc_bits
        generic map (
            Width_g => 1
        )
        port map (
            -- Input clock domain
            In_Clk      => A_Clk,
            In_Rst      => '0',
            In_Data(0)  => RstRqstB2A(RstRqstA2B'left),
            -- Output clock domain
            Out_Clk     => B_Clk,
            Out_Rst     => '0',
            Out_Data(0) => RstAckA2B
        );

end architecture;


