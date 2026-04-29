<img src="../Logo.png" alt="Logo" width="400">

# olo_base_hashtable

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_hashtable.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_hashtable.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_hashtable.json?cacheSeconds=0)

VHDL Source: [olo_base_hashtable](../../src/base/vhdl/olo_base_hashtable.vhd)

## Description

This component implements a synchronous [hashtable](https://en.wikipedia.org/wiki/Hash_table) capable of storing *std_logic_vector* key-value pairs.

The memory is described in a way that it utilizes RAM resources (Block-RAM or distributed RAM) available in FPGAs with commonly used tools. For this purpose [olo_base_ram_sdp](./olo_base_ram_sdp.md) is used.

## Generics

| Name              | Type      | Default   | Description                                                  |
| :--------------   | :-------- | -------   | :----------------------------------------------------------- |
| Depth_g           | positive  | -         | Number of storable elements. Must be a power of two |
| KeyWidth_g        | positive  | -         | Width of key |
| ValueWidth_g      | positive  | -         | Width of Value |
| Hash_g            | Hash_t    | "MODULO"  | Hashing algorithm used <br> |
| RamStyle_g        | string    | "auto"    | Passed to [*olo_base_ram_sdp*](./olo_base_ram_sdp.md). Refer to the documentation of this component for more info |
| RamBehavior_g     | string    | "RBW"     | Passed to [*olo_base_ram_sdp*](./olo_base_ram_sdp.md). Refer to the documentation of this component for more info  |
| ClearAfterReset_g | boolean   | true      | Clear memory after a reset to prevent erroneous values |

Current supported hash algorithms are:
* *CRC32*: Key is hashed using the CRC32 method
* *MODULO*: Key's value is used as-is, except for modulo against depth of hashtable to obtain a valid index

## Interfaces

### Synchronisation

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Axis Handshaking

| Name      | In/Out | Length        | Description                                  |
| :-------  | :----- | :--------     | :------------------------------------------- |
| In_Ready  | out    | 1             | Axi-Stream handshaking signal that hashtable is ready to accept an operation |
| In_Valid  | in     | 1             | Axi_Stream handshaking signal that an operation is requested |
| Out_Ready | in     | 1             | Axi-Stream handshaking signal that user is ready to accept data |
| Out_Valid | out    | 1             | Axi_Stream handshaking signal that hashtable has data for the user |

### Input

| Name     | In/Out | Length        | Default   | Latency (ticks) | Description                                  |
| :------- | :----- | :--------     | -------   | :--- | :------------------------------------------- |
| In_Key   | in     | _KeyWidth_g_   | -         | N/A | Input key                                    |
| In_Value | in     | _ValueWidth_g_ | -         | N/A | Input Value                                  |
| In_Write      | in     | 1         | -         | search_key + 1 | (Over)Write In_Key-In_Value pair                 |
| In_Read       | in     | 1         | -         | search_key + Out_Ready_delay + 1 | Read Out_Value corresponding to In_Key           |
| In_Remove     | in     | 1         | -         | search_key + cluster_comp*2 + 1 | Remove Key-Value pair corresponding to In_Key    |
| In_Clear      | in     | 1         | -         | Width_g | Clear All Key-Value pairs from memory            |
| In_NextKey    | in     | 1         | -         | distance_from_next_key | Find next valid Out_Key in memory                |

Only one operation must be given to the hashtable at a time

Latency of *search_key* is: *1 + element_position_in_cluster*

Latency of *cluster_comp* is: *1 + (cluster_size - element_position_in_cluster)*

### Output

| Name      | In/Out | Length           | Default | Description                                   |
| :-------- | :----- | :--------        | ------- | :-------------------------------------------- |
| Out_Key   | out    | _KeyWidth_g_      | N/A     | Stored key output |
| Out_Value | out    | _ValueWidth_g_    | N/A     | Output value                                  |
| Out_KeyUnknown    | out    | 1                | N/A     | _In_Key_ does not exist in the hashtable (WR/RM/RD operations)  |

### Status

| Name              | In/Out | Length           | Default | Description                                                     |
| :--------         | :----- | :--------------- | ------- | :----------------------                                         |
| Status_Busy       | out | 1 | N/A | Busy |
| Status_Full          | out    | 1                | N/A     | Full                                                            |
| Status_Pairs          | out    | _log2ceil(Depth_g)_+1 | N/A     | Number of Key-Value pairs stored |


## Architecture

### Notes

* Operations requested while hashtable isn't ready (_Out_Ready_ = '1') are ignored
* A supplementary `used` bit is stored in memory alongside each key-value pair to indicate which memory words are occupied (`used` = 1). The total width of the internal memory is thus: RamWidth = KeyWidth_g + ValueWidth_g + 1
* If the used *olo_base_sdp* is in an unknown state after reset, the memory must be cleared before accepting any operation to prevent the hashtable from finding erroneous `used` bits set to 1 when the hashtable should be empty. The 

### Operations

#### Key search

The hastable uses a hash function to obtain a memory index from the provided key. As the hashing could produce the same result for different keys,the hashtable uses [linear open-addressing](https://en.wikipedia.org/wiki/Open_addressing) to resolve those collisions: the following elements are checked until either the key or an empty spot is found, creating clusters (or search-chains). When a key is found, _Out_KeyUnknown_ is reset to '0' and set to '1' otherwise. A counter is also used to prevent endless looping when memory is full as there would be no empty spot to end the search on

The more pairs are stored, the more chances of collisions and thus the formation of clusters whose size rapidly reduces the performance of the hashtable. When performance is an important factor, the hashtable should be dimensioned such that it never comes close to being full 

#### Read

Read searches for _In_Key_ in the hashtable. If the key is known, _Out_KeyUnknown_ is reset and _Out_Value_ holds the associated value. Otherwise, _Out_KeyUnknown_ is set and _Out_Value_ is undefined

#### Write 

Write searches for _In_Key_ in the hashtable. If the key is found, _Out_KeyUnknown_ is reset, _In_Value_ and _In_Key_ are stored in memory along with the `used` bit which is set to 1 to signal that this spot is occupied

When hashtable is full (_Status_Full_ = '1'), it is still possible to overwrite existing keys. In such cases, use _Out_KeyUnknown_ to known if new value was overwritten (_Out_KeyUnknown_ = '0') or ignored (_Out_KeyUnknown_ = '1')

#### Removal 

Removal searches for _In_Key_ in the hashtable. If the key is found, _Out_KeyUnknown is reset and cluster compression is performed before resetting the `used` bit of the last element of the cluster (see below). Otherwise, _Out_KeyUnknown_ is set

#### Clear

Clear goes through the whole memory and resets all `used` values, effectively emptying the whole hashtable from all its values

#### Next Key

Next Key sequentially and cyclically goes through the hash table looking for the next used spot and updates _Out_Key_ with the value. Modifying the internal memory may disturb the recovery of all the keys. To reliably obtain all values stored in the hashtable, use the following steps:

1. Invoke In_NextKey
2. Wait till hashtable is ready again to read Out_key
3. Repeat steps 1 and 2 _Out_Size_ times

It is important NOT to perform any other operation in between those steps as this would modify the internal memory and index registers and would most likely prevent coherent outputs

## Cluster compression

When removing key-value pairs, holes may be created in those clusters, rendering some elements inaccessible. Take for example the following situation:

Index | Data
---: | :---
0 | -
1 | -
2 | Data_1, hash = 2
3 | Data_2, hash = 2
4 | Data_3, hash = 3
5 | Data_4, hash = 5
6 | Data_5, hash = 6
7 | -

When searching for Data_3, hash would indicate to go search at index 3 but since Data_2 is already there, hashtable looks at the following index and finds Data_3. Trying to remove the element at index 3 would prevent further searches for Data_3 from succeeding

Index | Data
---: | :---
0 | -
1 | -
2 | Data_1, hash = 2
3 | -
4 | Data_3, hash = 3 (now inaccessible)
5 | Data_4, hash = 5
6 | Data_5, hash = 6
7 | -

When searching for Data_3, hash would redirect to index 3 but since memory is empty here, the hashtable would believe that Data_3 doesn't exist. Search chain must then be rebuilt by copying subsequent elements back into the cluster if their hash corresponds

Index | Data
---: | :---
0 | -
1 | -
2 | Data_1, hash = 2
3 | Data_3, hash = 3 (accessible again)
4 | -
5 | Data_4, hash = 5 (not moved because already at the right place)
6 | Data_5, hash = 6
7 | -

Note that in this implementation, only the last element of the cluster is actually removed (memory written to 0). In practice, the cluster is first rebuilt, (possibly squashing the data to remove) and then the last element of the cluster (possibly the element to remove if it was the sole element of the cluster) is emptied. This strategy simplifies the state machine necessary to remove an element

Note also that memory is used cyclically and thus, elements at indices 7 and 0 would be considered as part of the same cluster. When reconstituting the cluster, the following equation is used to determine if an element's hash places it outside the search chain (cluster broken by remove):

wr_idx < rd_idx && (hash <= wr_idx || hash > rd_idx) || rd_idx <= wr_idx && hash > rd_idx && hash <= wr_idx

Where `wr_idx` is the index of the current "hole" in the cluster, `rd_idx` is a following element of the cluster and `hash` is the hash of the element at `rd_idx`. When the equation is true, the element at `rd_idx` is copied at `wr_idx`. Once an empty element is found, the cluster is complete and the last copied element is emptied. Here's a more complete example using compression-first as explained above:

Idx | Init  | Compression | Removal | Cmp | Rm | Cmp | Rm | Cmp | Rm | Cmp | Rm
---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---
0   |       |       |       |       |       |       |       |       |       |       | 
1   |       |       |       |       |       |       |       |       |       |       | 
2   |       |       |       |       |       |       |       |       |       |       | 
3   |       |       |       |       |       |       |       |       |       |       | 
4   | A(4)  | A(4)  | *A(4)*  | C(4)  | *C(4)*  | E(4)  | *E(4)*  | J(4)  | ***J(4)***  |    
5   | *B(4)*  | C(4)  | C(4)  | D(5)  | D(5)  | D(5)  | D(5)  | D(5)  | D(5)  | D(5)  | D(5)  
6   | C(4)  | D(5)  | D(5)  | E(4)  | E(4)  | F(5)  | F(5)  | F(5)  | F(5)  | F(5)  | F(5)  
7   | D(5)  | E(4)  | E(4)  | F(5)  | F(5)  | G(7)  | G(7)  | G(7)  | G(7)  | G(7)  | G(7)  
8   | E(4)  | F(5)  | F(5)  | G(7)  | G(7)  | H(5)  | H(5)  | H(5)  | H(5)  | H(5)  | H(5)  
9   | F(5)  | G(7)  | G(7)  | H(5)  | H(5)  | J(4)  | J(4)  | **J(4)**  |       |       | 
10  | G(7)  | H(5)  | H(5)  | I(10) | I(10) | I(10) | I(10) | I(10) | I(10) | I(10) | I(10)
11  | H(5)  | I(10) | I(10) | J(4)  | J(4)  | **J(4)**  |       |       |       |       | 
12  | I(10) | J(4)  | J(4)  | **J(4)**  |       |       |       |       |       |       | 
13  | J(4)  | **J(4)**  |       |       |       |       |       |       |       |       | 
14  |       |       |       |       |       |       |       |       |       |       | 
15  |       |       |       |       |       |       |       |       |       |       | 

In the special case where an element must be removed from a full hashtable, the state machine would run endlessly as there is no empty memory spot to signal the end of a cluster. To prevent this, a counter is used to detect when the memory was fully checked


