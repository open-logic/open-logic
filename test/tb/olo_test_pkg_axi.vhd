---------------------------------------------------------------------------------------------------
-- Copyright (c) 2017 by Paul Scherrer Institute, Switzerland
-- Copyright (c) 2024 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Package to simplify the usage of AXI interfaces in testbenches.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library olo;
    use olo.olo_base_pkg_math.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_test_pkg_axi is

    type axi_ms_t is record
        -- Read address channel
        ar_id     : std_logic_vector;                -- Read address ID. This signal is the identification tag for the read address group of signals.
        ar_addr   : std_logic_vector;                -- Read address. This signal indicates the initial address of a read burst transaction.
        ar_len    : std_logic_vector(7 downto 0);    -- Burst length. The burst length gives the exact number of transfers in a burst
        ar_size   : std_logic_vector(2 downto 0);    -- Burst size. This signal indicates the size of each transfer in the burst
        ar_burst  : std_logic_vector(1 downto 0);    -- Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.
        ar_lock   : std_logic;                       -- Lock type. Provides additional information about the atomic characteristics of the transfer.
        ar_cache  : std_logic_vector(3 downto 0);    -- Memory type. This signal indicates how transactions are required to progress through a system.
        ar_prot   : std_logic_vector(2 downto 0);    -- Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.
        ar_qos    : std_logic_vector(3 downto 0);    -- Quality of Service, QoS identifier sent for each read transaction.
        ar_region : std_logic_vector(3 downto 0);    -- Region identifier. Permits a single physical interface on a slave to be used for multiple logical interfaces.
        ar_user   : std_logic_vector;                -- Optional User-defined signal in the read address channel.
        ar_valid  : std_logic;                       -- Write address valid. This signal indicates that the channel is signaling valid read address and control information.
        -- Read data channel
        r_ready   : std_logic;                       -- Read ready. This signal indicates that the master can accept the read data and response information.
        -- Write address channel
        aw_id     : std_logic_vector;                -- Write Address ID
        aw_addr   : std_logic_vector;                -- Write address
        aw_len    : std_logic_vector(7 downto 0);    -- Burst length. The burst length gives the exact number of transfers in a burst
        aw_size   : std_logic_vector(2 downto 0);    -- Burst size. This signal indicates the size of each transfer in the burst
        aw_burst  : std_logic_vector(1 downto 0);    -- Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.
        aw_lock   : std_logic;                       -- Lock type. Provides additional information about the atomic characteristics of the transfer.
        aw_cache  : std_logic_vector(3 downto 0);    -- Memory type. This signal indicates how transactions are required to progress through a system.
        aw_prot   : std_logic_vector(2 downto 0);    -- Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.
        aw_qos    : std_logic_vector(3 downto 0);    -- Quality of Service, QoS identifier sent for each write transaction.
        aw_region : std_logic_vector(3 downto 0);    -- Region identifier. Permits a single physical interface on a slave to be used for multiple logical interfaces.
        aw_user   : std_logic_vector;                -- Optional User-defined signal in the write address channel.
        aw_valid  : std_logic;                       -- Write address valid. This signal indicates that the channel is signaling valid write address and control information.
        -- Write data channel
        w_data    : std_logic_vector;                -- Write Data
        w_strb    : std_logic_vector;                -- Write strobes. This signal indicates which byte lanes hold valid data. There is one write strobe bit for each eight bits of the write data bus.
        w_last    : std_logic;                       -- Write last. This signal indicates the last transfer in a write burst.
        w_user    : std_logic_vector;                -- Optional User-defined signal in the write data channel.
        w_valid   : std_logic;                       -- Write valid. This signal indicates that valid write data and strobes are available.
        -- Write response channel
        b_ready   : std_logic;                       -- Write response ready. This signal indicates that the master can accept a write response.
    end record;

    type axi_sm_t is record
        -- Read address channel
        ar_ready : std_logic;                        -- Read address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
        -- Read data channel
        r_id     : std_logic_vector;                 -- Read ID tag. This signal is the identification tag for the read data group of signals generated by the slave.
        r_data   : std_logic_vector;                 -- Read Data
        r_resp   : std_logic_vector(1 downto 0);     -- Read response. This signal indicates the status of the read transfer.
        r_last   : std_logic;                        -- Read last. This signal indicates the last transfer in a read burst.
        r_user   : std_logic_vector;                 -- Optional User-defined signal in the read address channel.
        r_valid  : std_logic;                        -- Read valid. This signal indicates that the channel is signaling the required read data.
        -- Write address channel
        aw_ready : std_logic;                        -- Write address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
        -- Write data channel
        w_ready  : std_logic;                        -- Write ready. This signal indicates that the slave can accept the write data.
        -- Write response channel
        b_id     : std_logic_vector;                 -- Response ID tag. This signal is the ID tag of the write response.
        b_resp   : std_logic_vector(1 downto 0);     -- Write response. This signal indicates the status of the write transaction.
        b_user   : std_logic_vector;                 -- Optional User-defined signal in the write response channel.
        b_valid  : std_logic;                        -- Write response valid. This signal indicates that the channel is signaling a valid write response.
    end record;

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_test_pkg_axi is

end package body;

