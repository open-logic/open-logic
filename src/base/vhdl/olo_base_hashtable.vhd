library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_base_pkg_logic.all;
    use olo.olo_base_pkg_string.all;

entity olo_base_hashtable is
    generic (
        Depth_g                 : positive;
        KeyWidth_g              : positive;
        ValueWidth_g            : positive;
        Hash_g                  : string   := "CRC32";
        RamStyle_g              : string   := "auto";
        RamBehavior_g           : string   := "RBW";
        ClearAfterReset_g       : boolean  := true
    );
    port (
        -- Sync interface --
        Clk               : in    std_logic;
        Rst               : in    std_logic;
        -- Input Interface --
        -- Data
        In_Key            : in    std_logic_vector(KeyWidth_g-1 downto 0);
        In_Value          : in    std_logic_vector(ValueWidth_g-1 downto 0);
        -- Operations
        In_Write          : in    std_logic;
        In_Read           : in    std_logic;
        In_Remove         : in    std_logic;
        In_Clear          : in    std_logic;
        In_NextKey        : in    std_logic;
        -- AXI Handshaking
        In_Valid          : in    std_logic;
        In_Ready          : out   std_logic;
        -- Output Interface --
        -- Data
        Out_Key           : out   std_logic_vector(KeyWidth_g-1 downto 0);
        Out_Value         : out   std_logic_vector(ValueWidth_g-1 downto 0);
        -- AXI Handshaking
        Out_Valid         : out   std_logic;
        Out_Ready         : in    std_logic;
        -- Result
        Out_KeyUnknown    : out   std_logic;
        -- Status Interface --
        Status_Busy       : out   std_logic;
        Status_Full       : out   std_logic;
        Status_Pairs      : out   std_logic_vector(log2ceil(Depth_g) downto 0)
    );
end entity;

architecture rtl of olo_base_hashtable is

    -- Constant case Hash_g
    constant Hash_c : string := toUpper(Hash_g);

    -- Width of hashtable indices
    constant PairsIdx_c : integer := log2ceil(Depth_g);

    -- Hashtable storage data
    type Data_r is record
        key   : std_logic_vector(KeyWidth_g-1 downto 0);
        value : std_logic_vector(ValueWidth_g-1 downto 0);
        used  : std_logic;
    end record;

    -- Width of storage data
    constant DataWidth_c : integer := KeyWidth_g + ValueWidth_g + 1;
    -- Reset storage data value
    constant DataClear_c : Data_r := (
        (others => '0'),
        (others => '0'),
        '0'
    );

    -- Hashtable states
    type HtState_t is (Idle_s, SearchInit_s, NextKey_s, Clear_s, SearchKey_s, Write_s, Read_s, HashCompute_s, ClusterComp_s, Remove_s);

    -- Register signals
    type Reg_r is record
        ht_state     : HtState_t;
        pairs        : unsigned(PairsIdx_c downto 0);
        rd_idx       : unsigned(PairsIdx_c-1 downto 0);
        wr_idx       : unsigned(PairsIdx_c-1 downto 0);
        cnt          : unsigned(PairsIdx_c-1 downto 0);
        key_found    : std_logic;
        after_search : HtState_t;
        user_data    : Data_r;
        hash         : unsigned(PairsIdx_c-1 downto 0);
    end record;

    signal RegNext, RegCurr : Reg_r;
    signal Reset_State : HtState_t;

    signal Ram_WrAddr, Ram_RdAddr : unsigned(PairsIdx_c-1 downto 0);
    signal Ram_WrEna, Ram_RdEna   : std_logic;
    signal Ram_WrData, Ram_RdData : Data_r;
    signal Ram_RdDataVec          : std_logic_vector(DataWidth_c-1 downto 0);

    signal Hash_InKey      : std_logic_vector(KeyWidth_g-1 downto 0);
    signal Hash_Out        : unsigned(PairsIdx_c-1 downto 0);
    signal Hash_OutCluster : std_logic;

    signal Ht_Full : std_logic;

    -- User data serialisation function
    function toVector (data: Data_r) return std_logic_vector is
    begin
        return data.key & data.value & data.used;
    end function;

    -- User data deserialisation function
    function toData (vec: std_logic_vector) return Data_r is
    begin
        return (vec(KeyWidth_g + ValueWidth_g downto ValueWidth_g+1), vec(ValueWidth_g downto 1), vec(0));
    end function;

    -- CRC32 Hash Function
    function crc32Hash (data: std_logic_vector) return unsigned is
        -- CRC-32/ISCSI (Ref: https://crccalc.com/?crc=04&method=CRC-32/ISCSI&datatype=hex&outtype=bin)
        constant Hash_Crc32_Polynomial_c : std_logic_vector(31 downto 0) := x"1EDC6F41";
        -- Initial value chosen to have good distribution for hashtable
        constant Hash_Crc32_Init_c       : std_logic_vector(31 downto 0) := x"A5A5A5A5";

        -- Variables
        variable Lfsr_v  : std_logic_vector(31 downto 0) := Hash_Crc32_Init_c;
        variable InBit_v : std_logic;
    begin

        for bit in data'high downto 0 loop

            -- Input Handling
            InBit_v := data(bit) xor Lfsr_v(Lfsr_v'high);

            -- XOR hanling
            Lfsr_v := Lfsr_v(Lfsr_v'high-1 downto 0) & '0';
            if InBit_v = '1' then
                Lfsr_v := Lfsr_v xor Hash_Crc32_Polynomial_c;
            end if;

        end loop;

        return unsigned(Lfsr_v(PairsIdx_c-1 downto 0));
    end function;

begin

    -- Verification asserts
    -- Depth is power of 2
    assert log2(Depth_g) = log2ceil(Depth_g)
        report "###ERROR###: olo_base_hashtable - Depth_g must be a power of 2";
    -- Width of key must be bigger than width of indices to prevent memory underuse. Depth_g twice as big as number of keys tolerated to avoid clustering
    assert KeyWidth_g+1 >= PairsIdx_c
        report "olo_base_hashtable - Memory underuse over 2x: Not enough different key values to fill half the hashtable"
        severity warning;
    -- Check Hash Function
    assert Hash_c = "CRC32" or Hash_c = "MODULO"
        report "###ERROR###: olo_base_hashtable - Illegal value for Hash_g"
        severity error;

    p_ht_fsm : process (all) is
        variable Ops_v : std_logic_vector(4 downto 0);
    begin
        -- Default values
        RegNext    <= RegCurr; -- Keep current register values by default
        In_Ready   <= '0';
        Ram_RdEna  <= '0';
        Ram_RdAddr <= (others => '0');
        Ram_WrAddr <= (others => '0');
        Ram_WrEna  <= '0';
        Ram_WrData <= Ram_RdData; -- Write data is read data by default
        Out_Valid  <= '0';
        Hash_InKey <= Ram_RdData.key;
        Status_Busy <= '1';

        -- FSM
        case RegCurr.ht_state is
            when Idle_s =>
                -- Hashtable ready for new operation
                In_Ready <= '1';
                Status_Busy <= '0';
                if In_Valid = '1' then -- AXIS handshake
                    -- synthesis off
                    -- Only one operation can be requested at a time
                    Ops_v := (4 => In_Read,
                              3 => In_Write,
                              2 => In_Remove,
                              1 => In_NextKey,
                              0 => In_Clear);
                    assert (std_logic_vector(unsigned(Ops_v)-1) and Ops_v) = "00000"
                        report "olo_base_hashtable - Only one hashtable operation should be requested at a time";
                    -- synthesis on
                    RegNext.user_data <= (In_Key, In_Value, '1'); -- Memorise input data
                    if In_Write = '1' then
                        RegNext.after_search <= Write_s;
                        RegNext.ht_state     <= SearchInit_s;
                    elsif In_Read = '1' then
                        RegNext.after_search <= Read_s;
                        RegNext.ht_state     <= SearchInit_s;
                    elsif In_Remove = '1' then
                        RegNext.after_search <= HashCompute_s;
                        RegNext.ht_state     <= SearchInit_s;
                    elsif In_Clear = '1' then
                        RegNext.wr_idx   <= to_unsigned(0, RegNext.wr_idx'length);
                        RegNext.ht_state <= Clear_s;
                    elsif In_NextKey = '1' and RegCurr.pairs > 0 then
                        -- Pre-read next slot
                        Ram_RdEna        <= '1';
                        Ram_RdAddr       <= RegCurr.rd_idx + 1;
                        RegNext.rd_idx   <= RegCurr.rd_idx + 1;
                        RegNext.ht_state <= NextKey_s;
                    end if;
                end if;

            when SearchInit_s =>
                -- Init search at index given by hash
                Hash_InKey        <= RegCurr.user_data.key;
                RegNext.key_found <= '0';
                Ram_RdAddr        <= Hash_Out;
                Ram_RdEna         <= '1';
                RegNext.cnt       <= to_unsigned(0, RegNext.cnt'length);
                RegNext.rd_idx    <= Hash_Out;
                RegNext.ht_state  <= SearchKey_s;

            when SearchKey_s =>
                -- Key found
                if Ram_RdData.used = '1' and Ram_RdData.key = RegCurr.user_data.key then
                    RegNext.key_found <= '1';
                    RegNext.ht_state  <= RegCurr.after_search;
                    RegNext.cnt       <= to_unsigned(0, RegNext.cnt'length);
                    if RegCurr.after_search = HashCompute_s then
                        -- Setup cluster for compression
                        RegNext.rd_idx <= RegCurr.rd_idx + 1;
                        RegNext.wr_idx <= RegCurr.rd_idx;
                        Ram_RdAddr     <= RegCurr.rd_idx + 1;
                        Ram_RdEna      <= '1';
                    end if;
                -- Look for key further in the cluster
                elsif Ram_RdData.used = '1' and RegCurr.cnt < Depth_g-1 then
                    Ram_RdAddr     <= RegCurr.rd_idx + 1;
                    RegNext.rd_idx <= RegCurr.rd_idx + 1;
                    Ram_RdEna      <= '1';
                    RegNext.cnt    <= RegCurr.cnt + 1;
                -- Key not found
                else
                    RegNext.ht_state <= RegCurr.after_search;
                end if;

            when NextKey_s =>
                -- Read next index until a used one is found
                if Ram_RdData.used = '1' then
                    Out_Valid <= '1';
                    if Out_Ready = '1' then
                        RegNext.ht_state <= Idle_s;
                    end if;
                else
                    Ram_RdEna      <= '1';
                    Ram_RdAddr     <= RegCurr.rd_idx + 1;
                    RegNext.rd_idx <= RegCurr.rd_idx + 1;
                end if;

            when Clear_s =>
                -- Go through all indices and clear data
                Ram_WrEna      <= '1';
                Ram_WrData     <= DataClear_c;
                Ram_WrAddr     <= RegCurr.wr_idx;
                RegNext.wr_idx <= RegCurr.wr_idx + 1;
                Ram_RdEna      <= '1';
                if RegCurr.wr_idx = Depth_g-1 then
                    RegNext.pairs    <= to_unsigned(0, RegNext.pairs'length);
                    RegNext.ht_state <= Idle_s;
                end if;

            when Write_s =>
                -- Write value
                Ram_WrAddr <= RegCurr.rd_idx;
                if RegCurr.key_found = '1' then
                    -- Overwrite existing value
                    Ram_WrData.value <= RegCurr.user_data.value;
                    Ram_WrEna        <= '1';
                else
                    -- Write new key (if hashtable not full)
                    if Ht_Full = '0' then
                        Ram_WrEna     <= '1';
                        RegNext.pairs <= RegCurr.pairs + 1;
                    end if;
                    Ram_WrData <= RegCurr.user_data;
                end if;
                RegNext.ht_state <= Idle_s;

            when Read_s =>
                -- Read value
                if RegCurr.key_found = '1' then
                    Out_Valid <= '1';
                    if Out_Ready = '1' then -- AXIS handshake
                        RegNext.ht_state <= Idle_s;
                    end if;
                else
                    RegNext.ht_state <= Idle_s;
                end if;

            when HashCompute_s =>
                -- Compute hash
                -- Computed hash is stored here to break critical path (ram-hash-cluster)
                -- and hopefully improve performance
                RegNext.hash     <= Hash_Out;
                RegNext.ht_state <= ClusterComp_s;

            when ClusterComp_s =>
                -- Cluster compression
                Ram_WrAddr <= RegCurr.wr_idx;
                if RegCurr.key_found = '1' then
                    if Ram_RdData.used = '0' then -- Done
                        Ram_WrEna        <= '1';
                        RegNext.ht_state <= Remove_s;
                    else
                        if Hash_OutCluster = '1' then
                            -- Replace read element in cluster
                            Ram_WrEna      <= '1';
                            RegNext.wr_idx <= RegCurr.rd_idx;
                        end if;
                        if RegCurr.cnt = Depth_g-1 then -- Full hashtable cluster compressed
                            RegNext.ht_state <= Remove_s;
                        else
                            RegNext.ht_state <= HashCompute_s;
                            RegNext.cnt      <= RegCurr.cnt + 1;
                            RegNext.rd_idx   <= RegCurr.rd_idx + 1;
                            Ram_RdAddr       <= RegCurr.rd_idx + 1;
                            Ram_RdEna        <= '1';
                        end if;
                    end if;
                else
                    RegNext.ht_state <= Idle_s;
                end if;

            when Remove_s =>
                -- Removing last displaced key (or removed key if no cluster compression was necessary)
                Ram_WrData       <= DataClear_c;
                Ram_WrEna        <= '1';
                Ram_WrAddr       <= RegCurr.wr_idx;
                RegNext.pairs    <= RegCurr.pairs - 1;
                RegNext.ht_state <= Idle_s;

            -- Unrechable code
            -- coverage off
            when others =>
                null;
            -- coverage on
        end case;

    end process;

    -- Register process
    Reset_State <= Clear_s when ClearAfterReset_g else Idle_s; 
    p_reg : process (Clk, Rst) is
    begin
        if rising_edge(Clk) then
            RegCurr <= RegNext;

            -- Reset
            if Rst = '1' then
                RegCurr.ht_state <= Reset_State;
                RegCurr.pairs  <= to_unsigned(0, PairsIdx_c+1);
                RegCurr.wr_idx <= to_unsigned(0, PairsIdx_c);
                RegCurr.rd_idx <= to_unsigned(0, PairsIdx_c);
                RegCurr.cnt <= to_unsigned(0, PairsIdx_c);
                RegCurr.key_found <= '0';
                RegCurr.after_search <= Idle_s;
                RegCurr.user_data <= DataClear_c;
                RegCurr.hash <= to_unsigned(0, PairsIdx_c);
            end if;
        end if;
    end process;

    -- Hash
    g_hash_div : if Hash_c = "MODULO" generate
        Hash_Out <= unsigned(Hash_InKey(Hash_Out'range));
    end generate;

    g_hash_crc32 : if Hash_c = "CRC32" generate
        Hash_Out <= crc32Hash(Hash_InKey);
    end generate;

    -- Cyclically check if hash of read element falls outside of
    -- ]wr_idx;rd_idx] interval (search chain broken by remove)
    -- LOGICAL EQUATION:
    -- R = (rd_idx > wr_idx)((hash <= wr_idx) + (hash > rd_idx)) +
    -- (rd_idx < wr_idx)((hash <= wr_idx)(hash > rd_idx)) =
    -- A(B+C) + DBC
    -- 2 assumptions could allow us to simplify it:
    -- * rd_idx and wr_idx are never equal -> D = !A
    -- * When rd_idx <= wr_idx (!A), hash<rd_idx and hash>wr_idx
    --  cannot exist -> !A!B!C is undefined
    -- With the 2 previous assumptions, equation can be rewritten
    -- R = A(!BC + B!C) + !A(BC + !B!C) = A xor !(B xor C)
    Hash_OutCluster <= '1' when ((RegCurr.rd_idx > RegCurr.wr_idx) and ((RegCurr.hash <= RegCurr.wr_idx) or (RegCurr.hash > RegCurr.rd_idx))) or
                                ((RegCurr.rd_idx < RegCurr.wr_idx) and ((RegCurr.hash <= RegCurr.wr_idx) and (RegCurr.hash > RegCurr.rd_idx))) else
                       '0';

    -- Ram
    i_olo_base_ram_sdp : entity olo.olo_base_ram_sdp
        generic map (
            Depth_g       => Depth_g,
            Width_g       => DataWidth_c,
            RamStyle_g    => RamStyle_g,
            RamBehavior_g => RamBehavior_g
        )
        port map (
            Clk     => Clk,
            Wr_Addr => std_logic_vector(Ram_WrAddr),
            Wr_Ena  => Ram_WrEna,
            Wr_Data => toVector(Ram_WrData),
            Rd_Addr => std_logic_vector(Ram_RdAddr),
            Rd_Ena  => Ram_RdEna,
            Rd_Data => Ram_RdDataVec
        );

    Ram_RdData <= toData(Ram_RdDataVec);

    -- Outputs
    Status_Pairs   <= std_logic_vector(RegCurr.pairs);
    Ht_Full        <= '1' when RegCurr.pairs = Depth_g else '0';
    Status_Full    <= Ht_Full;
    Out_KeyUnknown <= not(RegCurr.key_found);
    Out_Key        <= Ram_RdData.key;
    Out_Value      <= Ram_RdData.value;

end architecture;
