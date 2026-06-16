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
correctable single-bit error (SEC) on it, refreshing the stored codeword before a second upset can turn a correctable
error into an uncorrectable one. It is **opportunistic**: it issues bus requests only on cycles where the user is not
accessing the RAM, so the wrapper can give every user access priority and the scrubber never stalls the user port.

This core owns **both** the scrub FSM **and** the user/scrubber arbitration. To stay reusable across the single- and
dual-port wrappers it presents a generic **write-channel + read-channel** interface: the user side
(`User_Wr_*` / `User_Rd_*`) carries the wrapper's user requests, and the RAM side (`Ram_Wr_*` / `Ram_Rd_*`) carries
the muxed requests to the wrapped RAM. The user always wins. A single-port wrapper ties both user channels to its one
shared port and collapses the two RAM channels back onto it; a dual-port wrapper maps the channels 1:1 onto the RAM's
write and read ports.

By default the scrubber is **free-running**: it advances as fast as user-idle cycles allow. An optional internal
**pacer** (enabled when _ScrubPeriod_g_ > 0.0) instead limits it to one full pass every _ScrubPeriod_g_ seconds and
raises _Scrub_Overrun_ if a pass cannot finish within its period -- see [Scrub Pacing](#scrub-pacing-optional).

For background on the SECDED scheme and the meaning of the ECC flags, see
[Open Logic Fault-Tolerance Principles](./olo_ft_principles.md).

## Generics

| Name               | Type     | Default | Description                                                  |
| :----------------- | :------- | ------- | :----------------------------------------------------------- |
| Depth_g            | positive | -       | Number of addresses to scrub. Matches the wrapped RAM depth. Must be at least 2. |
| Width_g            | positive | -       | Data word-width (decoded data, _not_ the codeword width).    |
| TotalReadLatency_g | positive | -       | End-to-end read latency of the wrapped ECC RAM, i.e. _RamRdLatency_g_ + _EccPipeline_g_. The FSM waits this many cycles between issuing a read and acting on the decoded ECC flags, and the read-valid shift register is this long. |
| SinglePortRam_g    | boolean  | false   | When `true`, the scrubber also drives the collapsed single-port address _Ram_Addr_ for [olo_ft_ram_sp_scrub](./olo_ft_ram_sp_scrub.md). Leave `false` (default) for the dual-port wrapper, which maps _Ram_Wr_Addr_ / _Ram_Rd_Addr_ 1:1 onto the RAM and ignores _Ram_Addr_. |
| ScrubClkHz_g       | real     | 100000000.0 | Frequency of _Clk_ in Hz, used **only** to size the optional pacer. Set it to the actual clock frequency; must be >= 1000.0 when the pacer is enabled (_ScrubPeriod_g_ > 0.0), and is ignored when free-running. |
| ScrubPeriod_g      | real     | 0.0     | Pacer period in seconds: one full scrub pass is started every _ScrubPeriod_g_ seconds (1 ms granularity). `0.0` (default) disables the pacer and leaves the scrubber free-running; any value > 0.0 enables it. |

## Interfaces

### Clock and Reset

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                                        |
| Rst  | in     | 1      | -       | Reset (high-active, synchronous). Returns the FSM to `Idle_s`, clears the address counter and the read-valid pipeline. |

### Scrubber Enable

| Name         | In/Out | Length | Default | Description                                                  |
| :----------- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Scrub_Enable | in     | 1      | '1'     | External enable. '0' holds the scrubber in `Idle_s` and gates its requests, without disturbing the user channels. Combined internally with user-busy (and, when the pacer is on, with the per-period enable) into the abort condition. |

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
| Ram_Wr_Data | out    | _Width_g_             | N/A     | Muxed write data (user data, or the registered decoded read data on a scrubber writeback). |

### RAM Read Channel (muxed)

| Name        | In/Out | Length                | Default | Description                                                  |
| :---------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Ram_Rd_Addr | out    | _ceil(log2(Depth_g))_ | N/A     | Muxed read address (user when _User_Rd_Ena_ = '1', else the scrub address). |
| Ram_Rd_Ena  | out    | 1                     | N/A     | Muxed read enable (`User_Rd_Ena OR` scrubber read). |

### Collapsed Single-Port Address

| Name     | In/Out | Length                | Default | Description                                                  |
| :------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Ram_Addr | out    | _ceil(log2(Depth_g))_ | N/A     | Single physical RAM address used by single-port wrappers: the write address when a write is active, else the read address. Driven only when _SinglePortRam_g_ = true (tied to 0 otherwise). |

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
| User_Rd_Valid | out    | 1      | N/A     | User-facing read valid: _Ram_Rd_Valid_ with the scrubber-owned read cycles masked out. The wrapper forwards it straight to its user read-valid output. |

### Scrub Status

All status outputs are clean, directly countable one-cycle pulses; no external qualifier is needed.

| Name           | In/Out | Length | Default | Description                                                  |
| :------------- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Scrub_EccSec   | out    | 1      | N/A     | Pulses '1' for one cycle when a scrubber-issued read observed a single-bit error (SEC); gated internally so user reads never appear here. The scrubber writes that address back, unless a user access (or _Scrub_Enable_ = '0') aborts the operation, in which case the address is retried. |
| Scrub_EccDed   | out    | 1      | N/A     | Pulses '1' for one cycle when a scrubber-issued read observed a double-bit error (DED). The scrubber **does not** write the cell back (the corrected value is unreliable). |
| Scrub_PassDone | out    | 1      | N/A     | Pulses '1' for one cycle when the address counter rolls over from _Depth_g_-1 back to 0, marking a completed pass over the whole memory. |
| Scrub_Overrun  | out    | 1      | N/A     | Pacer watchdog. Pulses '1' (and a simulation warning fires) when a new scrub period begins before the previous pass completed. Tied '0' when the pacer is disabled (_ScrubClkHz_g_ = 0.0). |

## Detailed Description

### Arbitration

The request muxes are combinational and give the user priority on each channel independently:

```text
Scrub_Inhibit = User_Wr_Ena OR User_Rd_Ena OR NOT Scrub_Enable OR NOT ScrubActive

Ram_Wr_Addr = User_Wr_Addr  when User_Wr_Ena='1'  else ScrubAddr
Ram_Wr_Ena  = User_Wr_Ena   OR  <scrub writeback>
Ram_Wr_Data = User_Wr_Data  when User_Wr_Ena='1'  else <registered decoded read data>
Ram_Rd_Addr = User_Rd_Addr  when User_Rd_Ena='1'  else ScrubAddr
Ram_Rd_Ena  = User_Rd_Ena   OR  <scrub read>

-- single-port collapse, only when SinglePortRam_g = true
Ram_Addr    = User_Wr_Addr  when User_Wr_Ena='1'  else  User_Rd_Addr when User_Rd_Ena='1'  else ScrubAddr
```

`Scrub_Inhibit` gates the FSM: the scrubber asserts its own read/writeback only while `Scrub_Inhibit` is '0', so the
user is never overridden. `ScrubActive` is the pacer's per-period enable; it is tied '1' (always active) when the pacer
is disabled (see [Scrub Pacing](#scrub-pacing-optional)). For a single-port wrapper (`SinglePortRam_g = true`) the
scrubber additionally collapses the write/read addresses onto one physical port via `Ram_Addr` (the write address wins
when a write is active); because the user always wins, `ScrubAddr` is selected only on cycles the user is idle.

### Scrubber FSM

The FSM walks one address per scrub operation through three states: `Idle_s` issues the read, `ReadWait_s` waits out
the read latency, and `Decide_s` acts on the (registered) decoded result and advances the address. Let
`L = TotalReadLatency_g` and let `T` be the cycle the read is issued:

- **`Idle_s`** -- while `Scrub_Inhibit = '0'`, issue a scrub read at the current `ScrubAddr`, load `WaitCnt = 1` and go
  to `ReadWait_s`. While `Scrub_Inhibit = '1'`, stay in `Idle_s`.
- **`ReadWait_s`** -- count `WaitCnt` up until the decoded response is due (`WaitCnt = L`, i.e. cycle `T+L`), then go to
  `Decide_s`.
- **`Decide_s`** (cycle `T+L+1`) -- act on the **registered** decoder flags captured at `T+L`. If the read was
  SEC-correctable (`EccSec = '1'` and `EccDed = '0'`) assert the writeback so the corrected word (also registered) is
  written back this cycle. Advance `ScrubAddr` (pulsing `Scrub_PassDone` on rollover) and return to `Idle_s`.

The decoder response is **registered every cycle**, and `Decide_s` consumes the registered copy rather than the live
decoder output. This splits the RAM-read -> decode -> re-encode -> RAM-write path across two clock cycles instead of one
long combinational loop, which lets the scrubbing wrapper meet timing on par with the non-scrubbing ECC RAM.

**Abort.** If `Scrub_Inhibit` goes high during `ReadWait_s` or `Decide_s`, the FSM drops back to `Idle_s` immediately
**without advancing `ScrubAddr` and without writing back**, so the same address is retried on the next idle slot. User
data is therefore always authoritative.

### Read-Valid Masking and Status Gating

An internal length-`L` shift register (`ValidPipe`) tracks every scrub read-issue and pulses on the cycle the read
returns from the decoder (`T+L`), decoupled from the FSM state, so it still pulses even when the FSM aborted in the
meantime. It serves two purposes:

- **Masking:** the user-facing read valid is `User_Rd_Valid = Ram_Rd_Valid AND NOT <scrub-return pulse>`, so a
  scrubber-owned read never surfaces as a user read.
- **Status gating:** `Scrub_EccSec` / `Scrub_EccDed` are the decoder flags ANDed with the scrub-return pulse, so they
  are clean one-cycle pulses on scrubber reads only -- directly countable, with no consumer-side qualification.

### Writeback Policy

Only **SEC** errors are written back. A clean read leaves the cell untouched (no unnecessary write traffic), and a
**DED** read is reported via `Scrub_EccDed` but **not** rewritten, because the decoder's data output is unreliable for
a double-bit error. A scrub pass therefore repairs all single-bit upsets and flags (but cannot fix) double-bit upsets.

### Scrub Pacing (optional)

By default (`ScrubPeriod_g = 0.0`) the scrubber is free-running: `ScrubActive` is tied '1' and the strobe primitives
below are optimized away. Setting `ScrubPeriod_g > 0.0` enables a pacer that limits scrubbing to one pass every
`ScrubPeriod_g` seconds:

- A [olo_base_strobe_gen](../base/olo_base_strobe_gen.md) produces a 1 kHz base tick from `ScrubClkHz_g`, which a
  [olo_base_strobe_div](../base/olo_base_strobe_div.md) divides by `round(ScrubPeriod_g * 1000)` to yield one period
  strobe every `ScrubPeriod_g` seconds (hence the 1 ms granularity). The cascade reaches long real-time periods
  (minutes to hours) that a single strobe generator could not.
- Each period strobe arms `ScrubActive` (only while `Scrub_Enable = '1'`); `ScrubActive` clears when the pass
  completes, so exactly one pass runs per period and the scrubber sits idle for the rest of it.
- If a period strobe arrives while the previous pass is still in progress, `Scrub_Overrun` pulses and a simulation
  warning fires. This is a watchdog for a `ScrubPeriod_g` set too short for the memory depth and the available idle
  bandwidth.

When the pacer is enabled (`ScrubPeriod_g > 0.0`), `ScrubClkHz_g` must be set to the actual `Clk` frequency and be
>= 1000.0; this is checked at elaboration.

### Constraints

The scrubber requires single-clock operation: it observes the wrapped RAM's read on the same clock that drives the
user port, so the scrubbing RAM wrappers are synchronous-only (no async read clock).

There is deliberately no `olo_ft_ram_tdp_scrub`: on a true-dual-port RAM both ports can be user-busy in any cycle
(and may run on independent clocks), so there is no port the scrubber could own opportunistically.
