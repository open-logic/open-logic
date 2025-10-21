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
        Hash_g : string := "LCG";
        LcgMult_g : positive := 1103515245; --For LCG. From GCC's implementation
        LcgIncr_g : positive := 12345; --For LCG. From GCC's implementation
        RamStyle_g : string := "auto";
        RamBehavior_g : string := "RBW";
        ClearAfterReset_g : boolean := true
    );
    port (
        Clk : in std_logic;
        Rst : in std_logic;
        In_Key : in std_logic_vector(KeyWidth_g-1 downto 0);
        In_Value : in std_logic_vector(ValueWidth_g-1 downto 0);
        Out_Key : out std_logic_vector(KeyWidth_g-1 downto 0);
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

    type ht_state_t is (IDLE, SEARCH_INIT, NEXT_KEY, CLEAR, SEARCH_KEY, WRITE, READ, CLUSTER_COMP, REMOVE);

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
    signal Hash_Out : unsigned(PAIRS_IDX-1 downto 0);
    signal Hash_OutCluster : std_logic;
    
    signal Ht_Full : std_logic;

    function to_vector (data: data_t) return std_logic_vector is
    begin
        return data.key & data.value & data.used;
    end function;

    function to_data (vec: std_logic_vector) return data_t is
    begin
        return (vec(KeyWidth_g + ValueWidth_g downto ValueWidth_g+1), vec(ValueWidth_g downto 1), vec(0));
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
        Ram_WrData <= Ram_RdData;
        Out_DataValid <= '0';
        Hash_InKey <= Ram_RdData.key;

        case reg_sp.ht_state is
            when IDLE =>
                Out_OpReady <= '1';
                if In_OpValid <= '1' then
                    reg_sn.user_data <= (In_Key, In_Value, '1');
                    if In_Write = '1' then
                        report "Attempting to write value with key " & integer'image(to_integer(unsigned(In_Key))) & " to hashtable" & LF;
                        reg_sn.after_search <= WRITE;
                        reg_sn.ht_state <= SEARCH_INIT;
                    elsif In_Read = '1' then
                        report "Attempting to read value with key " & integer'image(to_integer(unsigned(In_Key))) & " from hashtable" & LF;
                        reg_sn.after_search <= READ;
                        reg_sn.ht_state <= SEARCH_INIT;
                    elsif In_Remove = '1' then
                        report "Attempting to remove value with key " & integer'image(to_integer(unsigned(In_Key))) & " from hashtable" & LF;
                        Reg_sn.after_search <= REMOVE;
                        reg_sn.ht_state <= SEARCH_INIT;
                    elsif In_Clear = '1' then
                        report "Attempting to clear hashtable" & LF;
                        reg_sn.wr_idx <= to_unsigned(0, reg_sn.wr_idx'length);
                        reg_sn.ht_state <= CLEAR;
                    elsif In_NextKey = '1' and reg_sp.pairs > 0 then
                        report "Attempting to find next key in hashtable" & LF;
                        Ram_RdEna <= '1';
                        Ram_RdAddr <= reg_sp.rd_idx + 1;
                        reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                        reg_sn.ht_state <= NEXT_KEY;                        
                    end if;
                end if;

            when SEARCH_INIT =>
                Hash_InKey <= reg_sp.user_data.key;
                reg_sn.key_found <= '0';
                Ram_RdAddr <= Hash_Out;
                Ram_RdEna <= '1';
                reg_sn.hash <= Hash_Out;
                reg_sn.rd_idx <= Hash_Out;
                reg_sn.ht_state <= SEARCH_KEY;
                report "Initialising search at index " & integer'image(to_integer(Hash_Out));

            when NEXT_KEY =>
                if Ram_RdData.used = '1' then
                    report "Found next key: " & integer'image(to_integer(unsigned(In_Key))) & LF;
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
                    report "Hashtable Cleared";
                    reg_sn.pairs <= to_unsigned(0, reg_sn.pairs'length);
                    reg_sn.ht_state <= IDLE;
                end if;

            when SEARCH_KEY =>
                if Ram_RdData.used = '1' and Ram_RdData.key = reg_sp.user_data.key then
                    report "Found key";
                    reg_sn.key_found <= '1';
                    reg_sn.ht_state <= reg_sp.after_search;
                elsif Ram_RdData.used = '1' and reg_sp.rd_idx + 1 /= reg_sp.hash then
                    report "Key not at index " & integer'image(to_integer(reg_sp.rd_idx)) & ". Key here is " & integer'image(to_integer(unsigned(Ram_RdData.key)));
                    Ram_RdAddr <= reg_sp.rd_idx + 1;
                    reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                    Ram_RdEna <= '1';
                else
                    report "Key not found";
                    reg_sn.ht_state <= reg_sp.after_search;
                end if;

            when WRITE =>
                Ram_WrAddr <= reg_sp.rd_idx;
                if reg_sp.key_found = '1' then
                    report "Key overriden";
                    Ram_WrData.value <= reg_sp.user_data.value;
                    Ram_WrEna <= '1';
                else
                    if Ht_Full = '0' then
                        report "Writing new key";
                        Ram_WrEna <= '1';
                        reg_sn.pairs <= reg_sp.pairs + 1;
                    end if;
                    Ram_WrData <= reg_sp.user_data;
                end if;
                reg_sn.ht_state <= IDLE;

            when READ =>
                if reg_sp.key_found = '1' then
                    report "Reading key found to output";
                    Out_DataValid <= '1';
                    if In_DataReady <= '1' then
                        reg_sn.ht_state <= IDLE;
                    end if;
                else 
                    reg_sn.ht_state <= IDLE;
                end if;

            when REMOVE =>
                if reg_sp.key_found = '1' then
                    report "Removing key and performing cluster compression";
                    Ram_WrData <= DATA_CLEAR;
                    Ram_WrEna <= '1';
                    Ram_WrAddr <= reg_sp.rd_idx;
                    reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                    reg_sn.wr_idx <= reg_sp.rd_idx;
                    reg_sn.ht_state <= CLUSTER_COMP;
                    reg_sn.pairs <= reg_sp.pairs - 1;
                else
                    reg_sn.ht_state <= IDLE;
                end if;

            when CLUSTER_COMP =>
                Ram_WrAddr <= reg_sp.wr_idx;
                if Ram_RdData.used <= '0' then --Done
                    Ram_WrEna <= '1';
                    reg_sn.ht_state <= IDLE;
                    report "Cluster compression done";
                else
                    if Hash_OutCluster = '1' then
                        Ram_WrEna <= '1';
                        reg_sn.wr_idx <= reg_sp.rd_idx;
                    end if;
                    reg_sn.rd_idx <= reg_sp.rd_idx + 1;
                end if;

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

    hash_type_gen : if Hash_g = "LCG" generate
        
        Hash_Out <= lcg_prng(unsigned(Hash_InKey), 
            to_unsigned(LcgMult_g, log2ceil(LcgMult_g)), 
            to_unsigned(LcgIncr_g, log2ceil(LcgIncr_g)))(Hash_Out'range);
        
    else generate -- Do nothing, just take LSB

        Hash_Out <= unsigned(Hash_InKey(Hash_Out'range));

    end generate;

    -- Cyclically check if hash of read element falls outside of 
    -- ]wr_idx;rd_idx] interval (search chain broken by remove)
    -- EQUATION:
    -- R = (rd_idx > wr_idx)((hash >= wr_idx) + (hash > rd_idx)) + 
    -- (rd_idx < wr_idx)((hash >= wr_idx) + (hash > rd_idx)) = 
    -- A(B+C) + DBC
    -- 2 assumptions could allow us to simplify it:
    -- * rd_idx and wr_idx are never equal -> D = !A
    -- * When rd_idx <= wr_idx (!A), hash<rd_idx and hash>wr_idx 
    --  cannot exist -> !A!B!C is undefined and can be anything
    -- With the 2 previous assumptions, equation can be rewritten
    -- R = A(!BC + B!C) + !A(BC + !B!C) = A xor !(B xor C)
    Hash_OutCluster <= '1' when (reg_sp.rd_idx > reg_sp.wr_idx) and ((Hash_Out >= reg_sp.wr_idx) or (Hash_Out > reg_sp.rd_idx)) or
        (reg_sp.rd_idx < reg_sp.wr_idx) and ((Hash_Out >= reg_sp.wr_idx) or (Hash_Out > reg_sp.rd_idx)) else '0';

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
    Ram_RdData <= to_data(Ram_RdData_vec);

    Out_Pairs <= std_logic_vector(reg_sp.pairs);
    Ht_Full <= '1' when reg_sp.pairs = Depth_g else '0';
    Out_Full <= Ht_Full;
    Out_KeyUnknown <= not(reg_sp.key_found);
    Out_Key <= Ram_RdData.key;
    Out_Value <= Ram_RdData.value;

end architecture;