<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_private_scrubber

[Back to **Entity List**](../EntityList.md)

## Status Information

VHDL Source: [olo_ft_private_scrubber](../../src/ft/vhdl/olo_ft_private_scrubber.vhd)

**Internal building block.** This entity is the private opportunistic-scrubber core instantiated by the scrubbing RAM
wrappers [olo_ft_ram_sp_scrub](./olo_ft_ram_sp_scrub.md) and [olo_ft_ram_sdp_scrub](./olo_ft_ram_sdp_scrub.md). It is
**not intended for direct end-user instantiation** and is documented here so the scrub wrappers can reference its
behavior in one place. It carries no ECC logic of its own; it only schedules and arbitrates reads and writebacks
against an already-ECC-protected RAM.

## Description

The scrubber walks the RAM address space autonomously and rewrites a word whenever the wrapped RAM reports a
correctable single-bit error (SEC) on it, refreshing the stored codeword before a second upset can turn a
correctable error into an uncorrectable one. It is **opportunistic**: it issues bus requests only on cycles where
the user is not accessing the RAM, so the wrapper can give every user access priority and the scrubber never stalls
the user port.

This core owns **both** the scrub FSM **and** the user/scrubber arbitration. To stay reusable across the single- and
dual-port wrappers it presents a generic **write-channel + read-channel** interface: the user side
(`User_Wr_*` / `User_Rd_*`) carries the wrapper's user requests, and the RAM side (`Ram_Wr_*` / `Ram_Rd_*`) carries
the muxed requests to the wrapped RAM. The user always wins. A single-port wrapper ties both user channels to its one
shared port and collapses the two RAM channels back onto it; a dual-port wrapper maps the channels 1:1 onto the RAM's
write and read ports.

For background on the SECDED scheme and the meaning of the ECC flags, see
[Open Logic Fault-Tolerance Principles](./olo_ft_principles.md).

## Generics

| Name               | Type     | Default | Description                                                  |
| :----------------- | :------- | ------- | :----------------------------------------------------------- |
| Depth_g            | positive | -       | Number of addresses to scrub. Matches the wrapped RAM depth. |
| Width_g            | positive | -       | Data word-width (decoded data, _not_ the codeword width).    |
| TotalReadLatency_g | positive | -       | End-to-end read latency of the wrapped ECC RAM, i.e. _RamRdLatency_g_ + _EccPipeline_g_. The FSM waits this many cycles between issuing a read and sampling the decoded ECC flags, and the read-valid shift register is this long. |

## Interfaces

### Clock and Reset

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                                        |
| Rst  | in     | 1      | -       | Reset (high-active, synchronous). Returns the FSM to `Idle_s`, clears the address counter and the read-valid pipeline. |

### Scrubber Enable

| Name         | In/Out | Length | Default | Description                                                  |
| :----------- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Scrub_Enable | in     | 1      | '1'     | External enable. '0' holds the scrubber in `Idle_s` and gates its requests, without disturbing the user channels. Combined internally with user-busy into the abort condition. |

### User Write Channel (request)

| Name         | In/Out | Length                | Default | Description                                                  |
| :----------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| User_Wr_Addr | in     | _ceil(log2(Depth_g))_ | -       | User write address.                                         |
| User_Wr_Ena  | in     | 1                     | -       | User write enable. While '1' the user owns the write channel and the scrubber does not act. |
| User_Wr_Data | in     | _Width_g_             | -       | User write data.                                           |

### User Read Channel (request)

| Name         | In/Out | Length                | Default | Description                                                  |
| :----------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| User_Rd_Addr | in     | _ceil(log2(Depth_g))_ | -       | User read address.                                         |
| User_Rd_Ena  | in     | 1                     | -       | User read enable. While '1' the user owns the read channel and the scrubber does not act. |

### RAM Write Channel (muxed)

| Name        | In/Out | Length                | Default | Description                                                  |
| :---------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Ram_Wr_Addr | out    | _ceil(log2(Depth_g))_ | N/A     | Muxed write address (user when _User_Wr_Ena_ = '1', else the scrub address). |
| Ram_Wr_Ena  | out    | 1                     | N/A     | Muxed write enable (`User_Wr_Ena OR` scrubber writeback). |
| Ram_Wr_Data | out    | _Width_g_             | N/A     | Muxed write data (user data, or the decoded read data on a scrubber writeback). |

### RAM Read Channel (muxed)

| Name        | In/Out | Length                | Default | Description                                                  |
| :---------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Ram_Rd_Addr | out    | _ceil(log2(Depth_g))_ | N/A     | Muxed read address (user when _User_Rd_Ena_ = '1', else the scrub address). |
| Ram_Rd_Ena  | out    | 1                     | N/A     | Muxed read enable (`User_Rd_Ena OR` scrubber read). |

### Decoded RAM Read (response)

| Name          | In/Out | Length    | Default | Description                                                  |
| :------------ | :----- | :-------- | ------- | :----------------------------------------------------------- |
| Ram_Rd_Data   | in     | _Width_g_ | -       | Decoded (corrected) read data from the wrapped RAM. Also forwarded as the writeback payload. |
| Ram_Rd_EccSec | in     | 1         | -       | Single-error-corrected flag from the wrapped RAM's decoder.  |
| Ram_Rd_EccDed | in     | 1         | -       | Double-error-detected flag from the wrapped RAM's decoder.   |
| Ram_Rd_Valid  | in     | 1         | -       | Read-valid from the wrapped RAM. Pulses for every read, user or scrubber.                    |

### User Read Valid (response)

| Name          | In/Out | Length | Default | Description                                                  |
| :------------ | :----- | :----- | ------- | :----------------------------------------------------------- |
| User_Rd_Valid | out    | 1      | N/A     | User-facing read valid: _Ram_Rd_Valid_ with the scrubber-owned read cycles masked out (`Ram_Rd_Valid AND NOT Scrub_Rd_Valid`). The wrapper forwards it straight to its user read-valid output. |

### Scrub Status

| Name            | In/Out | Length | Default | Description                                                  |
| :-------------- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Scrub_Rd_Valid  | out    | 1      | N/A     | Pulses '1' on the cycle a scrub read returns from the decoder (one pulse per issued scrub read, _TotalReadLatency_g_ cycles after the read). Driven from a shift register, so it pulses even when the FSM aborted in the meantime. Also used internally to mask _User_Rd_Valid_. |
| Scrub_Rd_EccSec | out    | 1      | N/A     | Pass-through of _Ram_Rd_EccSec_. Qualify with _Scrub_Rd_Valid_. |
| Scrub_Rd_EccDed | out    | 1      | N/A     | Pass-through of _Ram_Rd_EccDed_. Qualify with _Scrub_Rd_Valid_. |
| Scrub_PassDone  | out    | 1      | N/A     | Pulses '1' for one cycle when the address counter rolls over from _Depth_g_-1 back to 0, marking a completed pass over the whole memory. |

## Detailed Description

### Arbitration

The request muxes are combinational and give the user priority on each channel independently:

```text
Scrub_Inhibit = User_Wr_Ena OR User_Rd_Ena OR NOT Scrub_Enable

Ram_Wr_Addr = User_Wr_Addr  when User_Wr_Ena='1'  else ScrubAddr
Ram_Wr_Ena  = User_Wr_Ena   OR  <scrub writeback>
Ram_Wr_Data = User_Wr_Data  when User_Wr_Ena='1'  else Ram_Rd_Data
Ram_Rd_Addr = User_Rd_Addr  when User_Rd_Ena='1'  else ScrubAddr
Ram_Rd_Ena  = User_Rd_Ena   OR  <scrub read>
```

The internal `Scrub_Inhibit` gates the FSM: the scrubber asserts its own read/writeback only while `Scrub_Inhibit` is
'0', so the user is never overridden.

### Scrubber FSM

The FSM walks one address per scrub operation through three states: `Idle_s` issues the read, `ReadWait_s` waits out
the read latency, and `Decide_s` acts on the decoded result and advances the address. Let `L = TotalReadLatency_g`:

- **`Idle_s`** - while `Scrub_Inhibit = '0'`, issue a scrub read at the current `ScrubAddr` and move on. For `L > 1`
  go to `ReadWait_s`; for `L = 1` the data is back next cycle so go straight to `Decide_s`. While
  `Scrub_Inhibit = '1'` stay in `Idle_s`.
- **`ReadWait_s`** - count `WaitCnt` up until the decoded data is due (`WaitCnt = L-1`), then go to `Decide_s`.
- **`Decide_s`** - sample `Ram_Rd_EccSec` / `Ram_Rd_EccDed`. If the read was SEC-correctable (`EccSec = '1'` and
  `EccDed = '0'`) assert the writeback so the corrected word is written back this cycle. Advance `ScrubAddr` (pulsing
  `Scrub_PassDone` on rollover) and return to `Idle_s`.

**Abort.** If `Scrub_Inhibit` goes high during `ReadWait_s` or `Decide_s`, the FSM drops back to `Idle_s` immediately
**without advancing `ScrubAddr` and without writing back**, so the same address is retried on the next idle slot. User
data is therefore always authoritative.

**Read-valid alignment and masking.** `Scrub_Rd_Valid` is generated by a length-`L` shift register fed by the scrub
read-issue pulse, decoupled from the FSM state. So even when the FSM aborts mid-flight, `Scrub_Rd_Valid` still pulses
on the cycle the read returns from the decoder. The core uses this to mask the user-facing read valid directly:
`User_Rd_Valid = Ram_Rd_Valid AND NOT Scrub_Rd_Valid`, so a scrubber-owned read never surfaces as a user read. The
wrapper simply forwards `User_Rd_Valid` to its user read-valid output.

### Writeback Policy

Only **SEC** errors are written back. A clean read leaves the cell untouched (no unnecessary write traffic), and a
**DED** read is reported via `Scrub_Rd_EccDed` but **not** rewritten, because the decoder's data output is unreliable
for a double-bit error. A scrub pass therefore repairs all single-bit upsets and flags (but cannot fix) double-bit
upsets.

### Constraints

The scrubber requires single-clock operation: it observes the wrapped RAM's read on the same clock that drives the
user port, so the scrubbing RAM wrappers are synchronous-only (no async read clock).
