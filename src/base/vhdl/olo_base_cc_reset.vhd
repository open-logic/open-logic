---------------------------------------------------------------------------------------------------
-- Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024-2025 by Oliver Bründler
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
--
-- Documentation:
-- https://github.com/open-logic/open-logic/blob/main/doc/base/olo_base_cc_reset.md
--
-- Note: The link points to the documentation of the latest release. If you
--       use an older version, the documentation might not match the code.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_attribute.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
entity olo_base_cc_reset is
    generic (
        SyncStages_g : positive range 2 to 4 := 2
    );
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
    signal RstALatch  : std_logic                    := '1';
    signal RstRqstB2A : std_logic_vector(2 downto 0) := (others => '0');
    signal RstAckB2A  : std_logic;

    -- Domain B signals
    signal RstBLatch  : std_logic                    := '1';
    signal RstRqstA2B : std_logic_vector(2 downto 0) := (others => '0');
    signal RstAckA2B  : std_logic;

    -- Synthesis attributes - suppress shift register extraction
    attribute shreg_extract of RstRqstB2A : signal is ShregExtract_SuppressExtraction_c;
    attribute shreg_extract of RstAckB2A  : signal is ShregExtract_SuppressExtraction_c;
    attribute shreg_extract of RstRqstA2B : signal is ShregExtract_SuppressExtraction_c;
    attribute shreg_extract of RstAckA2B  : signal is ShregExtract_SuppressExtraction_c;

    attribute syn_srlstyle of RstRqstB2A : signal is SynSrlstyle_FlipFlops_c;
    attribute syn_srlstyle of RstAckB2A  : signal is SynSrlstyle_FlipFlops_c;
    attribute syn_srlstyle of RstRqstA2B : signal is SynSrlstyle_FlipFlops_c;
    attribute syn_srlstyle of RstAckA2B  : signal is SynSrlstyle_FlipFlops_c;

    -- Synthesis attributes - preserve registers
    attribute dont_merge of RstRqstB2A : signal is DontMerge_SuppressChanges_c;
    attribute dont_merge of RstAckB2A  : signal is DontMerge_SuppressChanges_c;
    attribute dont_merge of RstRqstA2B : signal is DontMerge_SuppressChanges_c;
    attribute dont_merge of RstAckA2B  : signal is DontMerge_SuppressChanges_c;

    attribute preserve of RstRqstB2A : signal is Preserve_SuppressChanges_c;
    attribute preserve of RstAckB2A  : signal is Preserve_SuppressChanges_c;
    attribute preserve of RstRqstA2B : signal is Preserve_SuppressChanges_c;
    attribute preserve of RstAckA2B  : signal is Preserve_SuppressChanges_c;

    attribute syn_keep of RstRqstB2A : signal is SynKeep_SuppressChanges_c;
    attribute syn_keep of RstAckB2A  : signal is SynKeep_SuppressChanges_c;
    attribute syn_keep of RstRqstA2B : signal is SynKeep_SuppressChanges_c;
    attribute syn_keep of RstAckA2B  : signal is SynKeep_SuppressChanges_c;

    attribute syn_preserve of RstRqstB2A : signal is SynPreserve_SuppressChanges_c;
    attribute syn_preserve of RstAckB2A  : signal is SynPreserve_SuppressChanges_c;
    attribute syn_preserve of RstRqstA2B : signal is SynPreserve_SuppressChanges_c;
    attribute syn_preserve of RstAckA2B  : signal is SynPreserve_SuppressChanges_c;

    -- Synthesis attributes - async registers
    attribute async_reg of RstRqstB2A : signal is AsyncReg_TreatAsync_c;
    attribute async_reg of RstAckB2A  : signal is AsyncReg_TreatAsync_c;
    attribute async_reg of RstRqstA2B : signal is AsyncReg_TreatAsync_c;
    attribute async_reg of RstAckA2B  : signal is AsyncReg_TreatAsync_c;

begin

    -- Domain A
    p_a_rst_sync : process (RstBLatch, A_Clk) is
    begin
        if RstBLatch = '1' then
            RstRqstB2A <= (others => '1');
        elsif rising_edge(A_Clk) then
            RstRqstB2A <= RstRqstB2A(RstRqstB2A'left - 1 downto 0) & '0';
        end if;
    end process;

    p_a_rst : process (A_Clk) is
    begin
        if rising_edge(A_Clk) then
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
    p_b_rst_sync : process (RstALatch, B_Clk) is
    begin
        if RstALatch = '1' then
            RstRqstA2B <= (others => '1');
        elsif rising_edge(B_Clk) then
            RstRqstA2B <= RstRqstA2B(RstRqstA2B'left - 1 downto 0) & '0';
        end if;
    end process;

    p_b_rst : process (B_Clk) is
    begin
        if rising_edge(B_Clk) then
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
            Width_g      => 1,
            SyncStages_g => SyncStages_g
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
            Width_g      => 1,
            SyncStages_g => SyncStages_g
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


