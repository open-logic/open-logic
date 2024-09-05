------------------------------------------------------------------------------
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This is a synchronous packet FIFO. In contrast to a normal FIFO, it allows
-- dropping and repeating packets as well as detecting how many packets
-- there are in the FIFO.
-- The FIFO works in store-and-forward mode.
-- The FIFO assumes that all packets fit into the FIFO. Cut-through operation
-- as required to handle packets bigger than the FIFO is not iplemented.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Entity
------------------------------------------------------------------------------
entity olo_base_fifo_sync is
    generic ( 
        Width_g         : positive;                   
        Depth_g         : positive;                                 
        RamStyle_g      : string    := "auto";       
        RamBehavior_g   : string    := "RBW";
        MaxPackets_g    : positive  := 16
    );
    port (    
        -- Control Ports
          Clk           : in  std_logic;
          Rst           : in  std_logic;
          -- Input Data
          In_Data       : in  std_logic_vector(Width_g - 1 downto 0);
          In_Valid      : in  std_logic                                             := '1';
          In_Ready      : out std_logic;
          In_Last       : in  std_logic                                             := '1';
          -- ... Input to request skip, output to indicate drop (also due to size > FIFO)
          -- Output Data
          Out_Data      : out std_logic_vector(Width_g - 1 downto 0);
          Out_Valid     : out std_logic;
          Out_Ready     : in  std_logic                                             := '1';
          Out_Last      : out std_logic;
          -- Inputs for "next_paket" and "repeat packet"
          -- Status
          LevelWords    : out std_logic_vector(log2ceil(Depth_g+1)-1 downto 0);
          LevelPackets  : out std_logic_vector(log2ceil(MaxPackets_g+1)-1 downto 0)
          
    );
end entity;


------------------------------------------------------------------------------
-- Architecture
------------------------------------------------------------------------------
architecture rtl of olo_base_fifo_sync is

    type two_process_r is record
        WrLevel : std_logic_vector(In_Level'range);
        RdLevel : std_logic_vector(Out_Level'range);
        RdUp    : std_logic;
        WrDown  : std_logic;
        WrAddr  : std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
        RdAddr  : std_logic_vector(log2ceil(Depth_g) - 1 downto 0);
    end record;

    signal r, r_next : two_process_r;

    signal RamWr     : std_logic;
    signal RamRdAddr : std_logic_vector(log2ceil(Depth_g) - 1 downto 0);

begin

    p_comb : process(In_Valid, Out_Ready, Rst, r)
        variable v : two_process_r;
    begin
        -- hold variables stable
        v := r;

        -- Write side
        v.RdUp := '0';
        RamWr  <= '0';
        if unsigned(r.WrLevel) /= Depth_g and In_Valid = '1' then
            if unsigned(r.WrAddr) /= Depth_g - 1 then
                v.WrAddr := std_logic_vector(unsigned(r.WrAddr) + 1);
            else
                v.WrAddr := (others => '0');
            end if;
            RamWr  <= '1';
            v.RdUp := '1';
            if r.WrDown = '0' then
                v.WrLevel := std_logic_vector(unsigned(r.WrLevel) + 1);
            end if;
        elsif r.WrDown = '1' then
            v.WrLevel := std_logic_vector(unsigned(r.WrLevel) - 1);
        end if;

        -- Write side status
        if unsigned(r.WrLevel) = Depth_g then
            In_Ready  <= '0';
            Full <= '1';
        else
            In_Ready  <= '1';
            Full <= '0';
        end if;
        -- Artificially keep InRdy low during reset if required
        if (ReadyRstState_g = '0') and (Rst = '1') then
            In_Ready <= '0';
        end if;

        if AlmFullOn_g and unsigned(r.WrLevel) >= AlmFullLevel_g then
            AlmFull <= '1';
        else
            AlmFull <= '0';
        end if;

        -- Read side
        v.WrDown  := '0';
        if unsigned(r.RdLevel) /= 0 and Out_Ready = '1' then
            if unsigned(r.RdAddr) /= Depth_g - 1 then
                v.RdAddr := std_logic_vector(unsigned(r.RdAddr) + 1);
            else
                v.RdAddr := (others => '0');
            end if;
            v.WrDown := '1';
            if r.RdUp = '0' then
                v.RdLevel := std_logic_vector(unsigned(r.RdLevel) - 1);
            end if;
        elsif r.RdUp = '1' then
            v.RdLevel := std_logic_vector(unsigned(r.RdLevel) + 1);
        end if;
        RamRdAddr <= v.RdAddr;

        -- Read side status
        if unsigned(r.RdLevel) > 0 then
            Out_Valid   <= '1';
            Empty <= '0';
        else
            Out_Valid   <= '0';
            Empty <= '1';
        end if;

        if AlmEmptyOn_g and unsigned(r.RdLevel) <= AlmEmptyLevel_g then
            AlmEmpty <= '1';
        else
            AlmEmpty <= '0';
        end if;

        -- Assign signal
        r_next <= v;

    end process;

    -- Synchronous Outputs
    Out_Level <= r.RdLevel;
    In_Level  <= r.WrLevel;

    p_seq : process(Clk)
    begin
        if rising_edge(Clk) then
            r <= r_next;
            if Rst = '1' then
                r.WrLevel <= (others => '0');
                r.RdLevel <= (others => '0');
                r.RdUp    <= '0';
                r.WrDown  <= '0';
                r.WrAddr  <= (others => '0');
                r.RdAddr  <= (others => '0');
            end if;
        end if;
    end process;

    i_ram : entity work.olo_base_ram_sdp
        generic map (
            Depth_g         => Depth_g,
            Width_g         => Width_g,
            RamStyle_g      => RamStyle_g,
            RamBehavior_g   => RamBehavior_g
        )
        port map(
            Clk         => Clk,
            Wr_Addr     => r.WrAddr,
            Wr_Ena      => RamWr,
            Wr_Data     => In_Data,
            Rd_Addr     => RamRdAddr,
            Rd_Data     => Out_Data
        );

end architecture;
