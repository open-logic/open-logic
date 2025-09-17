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
| Hash_g            | Hash_t    | DIVISION  | Hashing algorithm used |
| RamStyle_g      | string   | "auto"  | Passed to [*olo_base_ram_sdp*](./olo_base_ram_sdp.md). Refer to the documentation of this component for more info |
| RamBehavior_g   | string   | "RBW"   | Passed to [*olo_base_ram_sdp*](./olo_base_ram_sdp.md). Refer to the documentation of this component for more info  |

Current supported hash algorithms are:
* *DIVISION*: Key's value is used as-is, except for modulo against depth of hashtable to obtain a valid index
* *CRC*: Key's value is hashed using *olo_base_crc*

## Interfaces

### Synchronisation

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Input Data

| Name     | In/Out | Length        | Default   | Description                                  |
| :------- | :----- | :--------     | -------   | :------------------------------------------- |
| In_Key   | in     | _KeyWidth_g_   | -         | Input key                                    |
| In_Value | in     | _ValueWidth_g_ | -         | Input Value                                  |

### Output Data

| Name      | In/Out | Length           | Default | Description                                   |
| :-------- | :----- | :--------        | ------- | :-------------------------------------------- |
| Out_Value | out    | _ValueWidth_g_    | N/A     | Output value                                  |
| Out_Key   | out    | _KeyWidth_g_      | N/A     | Stored key output                             |

### Operations

| Name          | In/Out | Length    | Default   | Latency | Description |
| :-------      | :----- | :-------- | -------   | :---- | :-------------------------------------------    |
| In_Write      | in     | 1         | -         | TODO | (Over)Write In_Key-In_Value pair                 |
| In_Read       | in     | 1         | -         | TODO | Read Out_Value corresponding to In_Key           |
| In_Remove     | in     | 1         | -         | TODO | Remove Key-Value pair corresponding to In_Key    |
| In_Clear      | in     | 1         | -         | TODO | Clear All Key-Value pairs from memory            |
| In_NextKey    | in     | 1         | -         | TODO | Find next valid Out_Key in memory                |

### Status

| Name              | In/Out | Length           | Default | Description                                                     |
| :--------         | :----- | :--------------- | ------- | :----------------------                                         |
| Out_Ready         | out    | 1                | N/A     | Ready for new operation                                         |
| Out_KeyUnknown    | out    | 1                | N/A     | _In_Key_ does not exist in the hashtable (WR/RM/RD operations)  |
| Out_Full          | out    | 1                | N/A     | Full                                                            |
| Out_Pairs          | out    | _IndexWidth_g_+1 | N/A     | Number of Key-Value pairs stored |


## Architecture

### Notes

* Operations requested while hashtable isn't ready (_Out_Ready_ = '1') are ignored
* A supplementary `used` bit is stored in memory alongside each key-value pair to indicate which memory words are occupied (`used` = 1). The total width of the internal memory is thus: RamWidth = KeyWidth_g + ValueWidth_g + 1
* If the used *olo_base_sdp* is in an unknown state after reset, the memory must be cleared before accepting any operation to prevent the hashtable from finding erroneous `used` bits set to 1 when the hashtable should be empty

### Operations

#### Key search

The hastable uses a hash function to obtain a memory index from the provided key. As the hashing could produce the same result for different keys,the hashtable uses [linear open-addressing](https://en.wikipedia.org/wiki/Open_addressing) to resolve those collisions: the following elements are checked until either the key or an empty spot is found, creating clusters (or search-chains). When a key is found, _Out_KeyUnknown_ is reset to '0' and set to '1' otherwise. A counter is also used to prevent endless looping when memory is full as there would be no empty spot to end the search on

The more pairs are stored, the more chances of collisions and thus the formation of clusters whose size rapidly reduces the performance of the hashtable. When performance is an important factor, the hashtable should be dimensioned such that it never comes close to being full 

#### Read

Read searches for _In_Key_ in the hashtable and updates _Out_Value_ if the key is found

#### Write 

Write searches for _In_Key_ (or an empty spot if the element isn't already in the hashtable) and then writes the _In_Value_ and _In_Key_ in memory along with a `used` value to signal that this spot is occupied

When hashtable is full (_Out_Full_ = '1'), it is still possible to overwrite existing keys. In such cases, use _Out_KeyUnknown_ to known if new value was overwritten (_Out_KeyUnknown_ = '0') or ignored (_Out_KeyUnknown_ = '1')

#### Removal 

Removal searches for _In_Key_ and (if key is found) sets the `used` bit to 0 before performing cluster compression (see below)

#### Clear

Clear goes through the whole memory and clears all `used` values

#### Next Key

Next Key sequentially and cyclically goes through the hash table looking for the next used spot and updates _Out_Key_ with the value. Modifying the internal memory may disturb the recovery of all the keys. To reliably obtain all values stored in the hashtable, use the following steps:

1. Invoke In_NextKey
2. Wait till hashtable is ready again to read Out_key
3. Repeat steps 1 and 2 _Out_Size_ times

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
6 | -
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
6 | -
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
6 | -
7 | -

Note that in this implementation, only the last element of the cluster is actually removed (memory written to 0). In practice, the cluster is first rebuilt, (possibly squashing the data to remove) and then the last element of the cluster (possibly the element to remove if it was the sole element of the cluster) is emptied. This strategy simplifies the state machine necessary to remove an element

Note also that memory is used cyclically and thus, elements at indices 7 and 0 would be considered as part of the same cluster. When reconstituting the cluster, the following equation is used to determine if an element's hash places it outside the search chain (cluster broken by remove):

$
wr\_idx < rd\_idx \wedge (hash <= wr\_idx \vee hash > rd\_idx) \vee rd\_idx <= wr\_idx \wedge hash > rd\_idx \wedge hash <= wr\_idx
$

Where `wr_idx` is the index of the current "hole" in the cluster, `rd_idx` is a following element of the cluster and `hash` is the hash of the element at `rd_idx`. When the equation is true, the element at `rd_idx` is copied at `wr_idx`. Once an empty element is found, the cluster is complete and the last copied element is emptied

In the special case where an element must be removed from a full hashtable, the state machine would run endlessly as there is no empty memory spot to signal the end of a cluster. To prevent this, a counter is used to detect when the memory was fully checked


