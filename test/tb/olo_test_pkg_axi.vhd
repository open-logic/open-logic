------------------------------------------------------------------------------
--  Copyright (c) 2017 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- Package to simplify the usage of AXI interfaces in testbenches.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library olo;
    use olo.olo_base_pkg_math.all;

------------------------------------------------------------------------------
-- Package Header
------------------------------------------------------------------------------
package olo_test_pkg_axi is

    type AxiMs_r is record
        -- Read address channel			                             
        ArId     : std_logic_vector;                -- Read address ID. This signal is the identification tag for the read address group of signals.
        ArAddr   : std_logic_vector;                -- Read address. This signal indicates the initial address of a read burst transaction.
        ArLen    : std_logic_vector(7 downto 0);    -- Burst length. The burst length gives the exact number of transfers in a burst
        ArSize   : std_logic_vector(2 downto 0);    -- Burst size. This signal indicates the size of each transfer in the burst
        ArBurst  : std_logic_vector(1 downto 0);    -- Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.
        ArLock   : std_logic;                       -- Lock type. Provides additional information about the atomic characteristics of the transfer.
        ArCache  : std_logic_vector(3 downto 0);    -- Memory type. This signal indicates how transactions are required to progress through a system.
        ArProt   : std_logic_vector(2 downto 0);    -- Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.
        ArQos    : std_logic_vector(3 downto 0);    -- Quality of Service, QoS identifier sent for each read transaction.
        ArRegion : std_logic_vector(3 downto 0);    -- Region identifier. Permits a single physical interface on a slave to be used for multiple logical interfaces.
        ARUser   : std_logic_vector;                -- Optional User-defined signal in the read address channel.
        ARValid  : std_logic;                       -- Write address valid. This signal indicates that the channel is signaling valid read address and control information.
        -- Read data channel			                             
        RReady   : std_logic;                       -- Read ready. This signal indicates that the master can accept the read data and response information.
        -- Write address channel                                     
        AwId     : std_logic_vector;                -- Write Address ID
        AwAddr   : std_logic_vector;                -- Write address
        AwLen    : std_logic_vector(7 downto 0);    -- Burst length. The burst length gives the exact number of transfers in a burst
        AwSize   : std_logic_vector(2 downto 0);    -- Burst size. This signal indicates the size of each transfer in the burst
        AwBurst  : std_logic_vector(1 downto 0);    -- Burst type. The burst type and the size information, determine how the address for each transfer within the burst is calculated.
        AwLock   : std_logic;                       -- Lock type. Provides additional information about the atomic characteristics of the transfer.
        AwCache  : std_logic_vector(3 downto 0);    -- Memory type. This signal indicates how transactions are required to progress through a system.
        AwProt   : std_logic_vector(2 downto 0);    -- Protection type. This signal indicates the privilege and security level of the transaction, and whether the transaction is a data access or an instruction access.
        AwQos    : std_logic_vector(3 downto 0);    -- Quality of Service, QoS identifier sent for each write transaction.
        AwRegion : std_logic_vector(3 downto 0);   -- Region identifier. Permits a single physical interface on a slave to be used for multiple logical interfaces.
        AWUser   : std_logic_vector;                -- Optional User-defined signal in the write address channel.
        AwValid  : std_logic;                       -- Write address valid. This signal indicates that the channel is signaling valid write address and control information.
        -- Write data channel                                        
        WData    : std_logic_vector;                -- Write Data
        WStrb    : std_logic_vector;                -- Write strobes. This signal indicates which byte lanes hold valid data. There is one write strobe bit for each eight bits of the write data bus.
        WLast    : std_logic;                       -- Write last. This signal indicates the last transfer in a write burst.
        WUser    : std_logic_vector;                -- Optional User-defined signal in the write data channel.
        WValid   : std_logic;                       -- Write valid. This signal indicates that valid write data and strobes are available.
        -- Write response channel                                    
        BReady   : std_logic;                       -- Write response ready. This signal indicates that the master can accept a write response.
    end record;

    type AxiSm_r is record
        -- Read address channel			                             
        ArReady : std_logic;                        -- Read address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
        -- Read data channel			                             
        RId     : std_logic_vector;                 -- Read ID tag. This signal is the identification tag for the read data group of signals generated by the slave.
        RData   : std_logic_vector;                 -- Read Data
        RResp   : std_logic_vector(1 downto 0);     -- Read response. This signal indicates the status of the read transfer.
        RLast   : std_logic;                        -- Read last. This signal indicates the last transfer in a read burst.
        RUser   : std_logic_vector;                 -- Optional User-defined signal in the read address channel.
        RValid  : std_logic;                        -- Read valid. This signal indicates that the channel is signaling the required read data.
        -- Write address channel                                     
        AWReady : std_logic;                        -- Write address ready. This signal indicates that the slave is ready to accept an address and associated control signals.
        -- Write data channel                                        
        WReady  : std_logic;                        -- Write ready. This signal indicates that the slave can accept the write data.
        -- Write response channel                                    
        BId     : std_logic_vector;                 -- Response ID tag. This signal is the ID tag of the write response.
        BResp   : std_logic_vector(1 downto 0);     -- Write response. This signal indicates the status of the write transaction.
        BUser   : std_logic_vector;                 -- Optional User-defined signal in the write response channel.
        BValid  : std_logic;                        -- Write response valid. This signal indicates that the channel is signaling a valid write response.
    end record;

end olo_test_pkg_axi;

------------------------------------------------------------------------------
-- Package Body
------------------------------------------------------------------------------
package body olo_test_pkg_axi is

end olo_test_pkg_axi;

