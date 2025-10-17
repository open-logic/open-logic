library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;

entity olo_base_hashtable is
    generic (
        Depth_g : positive;
        KeyWidth_g : positive;
        ValueWidth_g : positive;
        Hash_g : string := "DIVISION";
        RamStyle_g : string := "auto";
        RamBehavior_g : string := "RBW";
        ClearAfterReset_g : boolean := true
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;
        In_Key : in std_logic_vector(KeyWidth_g-1 downto 0);
        In_Value : in std_logic_vector(ValueWidth_g-1 downto 0);
        Out_Key : out std_logic_vector(KeyWidth_g downto 0);
        Out_Value : out std_logic_vector(ValueWidth_g-1 downto 0);
        In_Write : in std_logic;
        In_Read : in std_logic;
        In_Remove : in std_logic;
        In_Clear : in std_logic;
        In_NextKey : in std_logic;
        In_OpValid : in std_logic;
        Out_OpReady : out std_logic;
        Out_DataValid : out std_logic;
        In_DataReady : in std_logic;
        Out_KeyUnknown : out std_logic;
        Out_Full : out std_logic;
        Out_Pairs : out std_logic_vector(log2ceil(Depth_g) downto 0)
    );
end entity olo_base_hashtable;

architecture rtl of olo_base_hashtable is

    constant PAIRS_IDX : integer := log2ceil(Depth_g);

    type data_t is record
        key : std_logic_vector(KeyWidth_g-1 downto 0);
        value : std_logic_vector(ValueWidth_g-1 downto 0);
        used : std_logic;
    end record;
    constant DATA_WIDTH : integer := KeyWidth_g + ValueWidth_g + 1;
    constant DATA_CLEAR : data_t := (
        (others => '0'),
        (others => '0'),
        '0'
    );

    type ht_state_t is (IDLE, SEARCH_INIT, WAIT_HASH, NEXT_KEY, CLEAR, SEARCH_KEY, WRITE, READ, CLUSTER_COMP, REMOVE);

    type reg_t is record
        ht_state : ht_state_t;
        pairs : unsigned(PAIRS_IDX downto 0);
        rd_idx : unsigned(PAIRS_IDX-1 downto 0);
        wr_idx : unsigned(PAIRS_IDX-1 downto 0); --May be useless (can use rd_idx for clear and hash for remove)
        hash : unsigned(PAIRS_IDX-1 downto 0);
        key_found : std_logic;
        after_search : ht_state_t;
        user_data : data_t;
    end record;
    constant REG_CLEAR : reg_t := (
        CLEAR,
        (others => '0'),
        (others => '0'),
        (others => '0'),
        (others => '0'),
        '0',
        IDLE,
        DATA_CLEAR
    );
    signal ResetVal : reg_t;

    signal reg_sn, reg_sp : reg_t;

    signal Ram_WrAddr, Ram_RdAddr : unsigned(PAIRS_IDX-1 downto 0);
    signal Ram_WrEna, Ram_RdEna : std_logic;
    signal Ram_WrData, Ram_RdData : data_t;
    signal Ram_RdData_vec : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal Hash_InKey : std_logic_vector(KeyWidth_g-1 downto 0);
    signal Hash_InReady, Hash_InValid, Hash_OutValid, Hash_OutReady : std_logic;
    signal Hash_Out : std_logic_vector(PAIRS_IDX-1 downto 0);
    
    signal Crc_Out : std_logic_vector(31 downto 0);

    signal Ht_Full : std_logic;

    function to_vector (data: data_t) return std_logic_vector is
    begin
        return data.key & data.value & data.used;
    end function;

    function to_data (vec: std_logic_vector) return data_t is
    begin
        return (vec(data_t.key'range), vec(data_t.value'range), vec(vec'low));
    end function;

begin

    process (all)
    begin
        reg_sn <= reg_sp;
        Out_OpReady <= '0';
        Ram_RdEna <= '0';
        Ram_RdAddr <= (others => '0');
        Ram_WrAddr <= (others => '0');
        Ram_WrEna <= '0';
        Hash_OutReady <= '0';
        Ram_WrData <= Ram_RdData;
        Out_DataValid <= '0';

        case reg_sp.ht_state is
            when IDLE =>
                Out_OpReady <= '1';
                if In_OpValid <= '1' then
                    reg_sn.user_data <= (In_Key, In_Value, '1');
                    if In_Write = '1' then
                        reg_sn.after_search <= WRITE;
                        reg_sn.ht_state <= SEARCH_INIT;
                    elsif In_Read = '1' then
                        reg_sn.after_search <= READ;
                        reg_sn.ht_state <= SEARCH_INIT;
                    elsif In_Remove = '1' then
                        Reg_sn.after_search <= CLUSTER_COMP;
                        reg_sn.ht_state <= SEARCH_INIT;
                    elsif In_Clear = '1' then
                        reg_sn.wr_idx <= to_unsigned(0, reg_sn.wr_idx'length);
                        reg_sn.ht_state <= CLEAR;
                    elsif In_NextKey = '1' and reg_sp.pairs > 0 then
                        Ram_RdEna <= '1';
                        Ram_RdAddr <= reg_sp.rd_idx + 1;
                        reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                        reg_sn.ht_state <= NEXT_KEY;                        
                    end if;
                end if;

            when SEARCH_INIT =>
                Hash_InKey <= reg_sp.user_data.key;
                Hash_InValid <= '1';
                reg_sn.key_found <= '0';
                if Hash_InReady = '1' then
                    reg_sn.ht_state <= WAIT_HASH;
                end if;

            when WAIT_HASH =>
                Hash_OutReady <= '1';
                if Hash_OutValid = '1' then
                    Ram_RdAddr <= unsigned(Hash_Out);
                    Ram_RdEna <= '1';
                    reg_sn.hash <= unsigned(Hash_Out);
                    reg_sn.rd_idx <= unsigned(Hash_Out);
                    reg_sn.ht_state <= SEARCH_KEY;
                end if;

            when NEXT_KEY =>
                if Ram_RdData.used = '1' then
                    Out_DataValid <= '1';
                    if In_DataReady = '1' then
                        reg_sn.ht_state <= IDLE;
                    end if;
                    
                else
                    Ram_RdEna <= '1';
                    Ram_RdAddr <= reg_sp.rd_idx + 1;
                    reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                end if;

            when CLEAR =>
                Ram_WrEna <= '1';
                Ram_WrData <= DATA_CLEAR;
                Ram_WrAddr <= reg_sp.wr_idx;
                reg_sn.wr_idx <= reg_sp.wr_idx + 1;
                Ram_RdEna <= '1';
                if reg_sp.wr_idx = Depth_g-1 then
                    reg_sn.ht_state <= IDLE;
                end if;

            when SEARCH_KEY =>
                if Ram_RdData.used = '1' and Ram_RdData.key = reg_sp.user_data.key then
                    reg_sn.key_found <= '1';
                    reg_sn.ht_state <= reg_sp.after_search;
                elsif Ram_RdData.used = '1' and reg_sp.rd_idx + 1 /= reg_sp.hash then
                    Ram_RdAddr <= reg_sp.rd_idx + 1;
                    reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                    Ram_RdEna <= '1';
                else
                    reg_sn.ht_state <= reg_sp.after_search;
                    if reg_sp.after_search <= CLUSTER_COMP then
                        reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                        reg_sn.wr_idx <= reg_sp.hash;
                    end if;
                end if;

            when WRITE =>
                Ram_WrAddr <= reg_sp.rd_idx;
                if reg_sp.key_found = '1' then
                    Ram_WrData.value <= reg_sp.user_data.value;
                    Ram_WrEna <= '1';
                else
                    if Ht_Full = '0' then
                        Ram_WrEna <= '1';
                    end if;
                    Ram_WrData <= reg_sp.user_data;
                end if;
                reg_sn.pairs <= reg_sp.pairs + 1;
                reg_sn.ht_state <= IDLE;

            when READ =>
                Out_DataValid <= '1';
                if In_DataReady <= '1' then
                    reg_sn.ht_state <= IDLE;
                end if;

            when CLUSTER_COMP =>
                if reg_sp.key_found = '0' then
                    reg_sn.ht_state <= IDLE;
                elsif Ram_RdData.used <= '0' then
                    reg_sn.ht_state <= REMOVE;
                else
                    -- Cyclically check if hash of read element falls outside of 
                    -- ]wr_idx;rd_idx] interval (search chain broken by remove)
                    -- EQUATION:
                    -- R = (rd_idx > wr_idx)((hash >= wr_idx) + (hash > rd_idx)) + 
                    -- (rd_idx < wr_idx)((hash >= wr_idx) + (hash > rd_idx)) = 
                    -- A(B+C) + DBC
                    -- 2 assumptions allow us to simplify it:
                    -- * rd_idx and wr_idx are never equal -> D = !A
                    -- * When rd_idx <= wr_idx (!A), hash<rd_idx and hash>wr_idx 
                    --  cannot exist -> !A!B!C is undefined and can be anything
                    -- With the 2 previous assumptions, equation can be rewritten
                    -- R = A(!BC + B!C) + !A(BC + !B!C) = A xor !(B xor C)
                    -- TODO
                    -- WARNING: Using entity with potential wait for hash forces us to use wait states for each hash calculated (many when doing cluster compression). This drastically reduces the performance of the hashtable when doing removes on very clustered memory. Instead, an immediate hashing function should be used
                    reg_sn.ht_state <= REMOVE;
                end if;

            when REMOVE =>
                reg_sn.ht_state <= IDLE;

            when others =>
                null;
        end case;

        ResetVal <= REG_CLEAR;
        if ClearAfterReset_g then
            ResetVal.ht_state <= CLEAR;
        end if;
        
    end process;

    process (Clk, Rst)
    begin
        if Rst = '1' then
            reg_sp <= ResetVal;
        elsif rising_edge(Clk) then
            reg_sp <= reg_sn;
        end if;
    end process;

    hash_type_gen : if Hash_g = "CRC" generate
        
        olo_base_crc_inst: entity olo.olo_base_crc
        generic map(
            DataWidth_g => KeyWidth_g,
            Polynomial_g => x"814141AB"
        )
        port map(
            Clk => Clk,
            Rst => Rst,
            In_Data => Hash_InKey,
            In_Ready => Hash_InReady,
            In_Valid => Hash_InValid,
            In_Last => '1',
            In_First => '1',
            Out_Crc => Crc_Out,
            Out_Valid => Hash_OutValid,
            Out_Ready => Hash_OutReady
        );
        Hash_Out <= Crc_Out(PAIRS_IDX-1 downto 0);
        
    else generate -- Hash_g = "DIVISION"

        Hash_Out <= Hash_InKey(PAIRS_IDX-1 downto 0);
        Hash_InReady <= '1';
        Hash_OutValid <= '1';

    end generate;

    olo_base_ram_sdp_inst: entity olo.olo_base_ram_sdp
     generic map(
        Depth_g => Depth_g,
        Width_g => DATA_WIDTH,
        RamStyle_g => RamStyle_g,
        RamBehavior_g => RamBehavior_g
    )
     port map(
        Clk => Clk,
        Wr_Addr => std_logic_vector(Ram_WrAddr),
        Wr_Ena => Ram_WrEna,
        Wr_Data => to_vector(Ram_WrData),
        Rd_Addr => std_logic_vector(Ram_RdAddr),
        Rd_Ena => Ram_RdEna,
        Rd_Data => Ram_RdData_vec
    );
    Ram_RdData.key <= Ram_RdData_vec(Ram_RdData.key'range);
    Ram_RdData.value <= Ram_RdData_vec(Ram_RdData.value'range);
    Ram_RdData.used <= Ram_RdData_vec(Ram_RdData_vec'low);

    Out_Pairs <= std_logic_vector(reg_sp.pairs);
    Ht_Full <= '1' when reg_sp.pairs = Depth_g else '0';
    Out_Full <= Ht_Full;
    Out_KeyUnknown <= not(reg_sp.key_found);
    Out_Key <= Ram_RdData.key;
    Out_Value <= Ram_RdData.value;

end architecture;