<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_ram_sp_scrub

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_ft_ram_sp_scrub.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_ft_ram_sp_scrub.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_ft_ram_sp_scrub.json?cacheSeconds=0)

VHDL Source: [olo_ft_ram_sp_scrub](../../src/ft/vhdl/olo_ft_ram_sp_scrub.vhd)

## Description

This component implements an **ECC-protected single-port RAM with an opportunistic memory scrubber**. It composes two
existing entities:

- [olo_ft_ram_sp](./olo_ft_ram_sp.md) - the SECDED-protected single-port RAM (encoder + RAM + decoder).
- [olo_ft_private_scrubber](./olo_ft_private_scrubber.md) - the private opportunistic scrubber FSM.

The user-facing interface is identical to [olo_ft_ram_sp](./olo_ft_ram_sp.md) plus a scrubber-enable input and four
scrubber-status outputs. ECC encoding/decoding is transparent; the scrubber additionally walks the address space
autonomously and writes corrected codewords back when a single-bit error is detected, refreshing the memory before a
second upset can accumulate into an uncorrectable double-bit error. Because the underlying RAM is single-port, the
scrubber only issues a read or a writeback on cycles where the user is doing neither (`WrEna = '0'` and `RdEna = '0'`).
User accesses are never stalled.

This is useful in **radiation-hardened** designs where single-event upsets (SEUs) can flip bits in memory cells.

For background on the SECDED scheme, the codeword layout, error injection semantics and the constraints that apply
across the _ft_ area, see [Open Logic Fault-Tolerance Principles](./olo_ft_principles.md).

## Generics

| Name           | Type     | Default | Description                                                  |
| :------------- | :------- | ------- | :----------------------------------------------------------- |
| Depth_g        | positive | -       | Number of addresses the RAM has. Must be at least 2.         |
| Width_g        | positive | -       | Number of data bits stored per address (word-width). The internal RAM is wider to accommodate ECC parity bits. |
| RamRdLatency_g | positive | 1       | Read latency of the wrapped RAM, _excluding_ ECC pipeline stages. Higher values can help close timing on the RAM read path. |
| RamStyle_g     | string   | "auto"  | Controls the RAM implementation resource. Passed through to [olo_base_ram_sp](../base/olo_base_ram_sp.md). |
| RamBehavior_g  | string   | "RBW"   | Controls the RAM behavior. <br>"RBW": Read-before-write<br>"WBR": Write-before-read |
| EccPipeline_g  | natural  | 0       | Number of pipeline register stages within the ECC decoder (range _0..2_). Total read latency is _RamRdLatency_g_ + _EccPipeline_g_ cycles. See [olo_ft_ram_sp](./olo_ft_ram_sp.md#ecc-pipeline) for details. |

## Interfaces

### Clock and Reset

| Name | In/Out | Length | Default | Description                                                  |
| :--- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                                        |
| Rst  | in     | 1      | -       | Reset (high-active, synchronous to _Clk_). Resets the scrubber FSM and the read-valid pipeline; apply a reset pulse after startup, since the scrubber's address counter does not self-initialize in simulation. The stored RAM contents are unaffected (block RAMs cannot be reset). |

### FT RAM Port

| Name     | In/Out | Length                | Default | Description                                                  |
| :------- | :----- | :-------------------- | ------- | :----------------------------------------------------------- |
| Addr     | in     | _ceil(log2(Depth_g))_ | -       | Address                                                      |
| WrEna    | in     | 1                     | '1'     | Write enable                                                 |
| WrData   | in     | _Width_g_             | -       | Write data                                                   |
| RdEna    | in     | 1                     | '1'     | Read enable. _RdValid_ pulses '1' exactly _RamRdLatency_g_+_EccPipeline_g_ cycles after each cycle on which _RdEna_ = '1'. Note: holding _RdEna_ = '1' permanently leaves no idle cycles and starves the scrubber entirely (see [Opportunistic Scrubbing](#opportunistic-scrubbing)); deassert it on cycles without an actual read. |
| RdData   | out    | _Width_g_             | N/A     | Read data (corrected if a single-bit error was detected)     |
| RdValid  | out    | 1                     | N/A     | Read-data valid. Pulses '1' only for reads the user issued; cycles consumed by the scrubber's own reads are masked out (see [Architecture](#architecture)). |
| RdEccSec | out    | 1                     | N/A     | Single error corrected flag. Unmasked pass-through of the decoder's SEC flag: qualify it with _RdValid_ = '1'. It also asserts on the return cycle of a scrubber-issued read (_RdValid_ = '0', _Scrub_Rd_Valid_ = '1'); scrubber events are reported on _Scrub_Rd_EccSec_. |
| RdEccDed | out    | 1                     | N/A     | Double error detected flag. Unmasked pass-through of the decoder's DED flag: qualify it with _RdValid_ = '1' (it also asserts on scrubber read returns). Read data is unreliable when the flag is set. |

### Error Injection (optional)

These ports drive the internal [olo_ft_ecc_encode](./olo_ft_ecc_encode.md) instance (via the wrapped
[olo_ft_ram_sp](./olo_ft_ram_sp.md)). Leave them unconnected for normal operation; see
[Open Logic Fault-Tolerance Principles - Error Injection](./olo_ft_principles.md#error-injection) for the shared
latched-strobe semantics.

> **Note on scrubber interaction.** `ErrInj_*` is design-for-test only. The encoder's injection latch is consumed by
> the very next encoder write, which in the scrub variant may be a scrubber writeback rather than the user's intended
> next write. Either drive `ErrInj_Valid = '1'` together with `WrEna = '1'` in the same cycle (immediate injection,
> bypasses the latch), or pause the scrubber with `Scrub_Enable = '0'` while the latch is preloaded - see
> [Pausing the Scrubber](#pausing-the-scrubber) for the deterministic sequence. For a single-bit (popcount-1) pattern
> the worst case is benign: a scrubber-corrupted cell is SEC-correctable and is repaired on the next pass. For
> popcount >= 2 patterns there is no such safety net: a scrubber writeback that consumes the latch leaves an
> uncorrectable (DED) word at the scrubbed address, which the SEC-only scrubber never rewrites. Always pause the
> scrubber before preloading multi-bit patterns.

| Name           | In/Out | Length                                                              | Default | Description                                                  |
| :------------- | :----- | :------------------------------------------------------------------ | ------- | :----------------------------------------------------------- |
| ErrInj_BitFlip | in     | _[eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(Width_g)_ | all 0   | Codeword-wide flip pattern. Each '1' bit XORs the corresponding bit of the stored codeword on the next write. Popcount 1 = SEC-correctable, popcount 2 = DED-detectable. |
| ErrInj_Valid   | in     | 1                                                                   | '0'     | Strobe that latches _ErrInj\_BitFlip_ into the encoder's pending-injection register. The latched pattern is applied to the next write. If _ErrInj\_Valid_ = '1' and _WrEna_ = '1' in the same cycle the pattern is applied directly without going through the latch. |

### Scrubber Control

| Name         | In/Out | Length | Default | Description                                                  |
| :----------- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Scrub_Enable | in     | 1      | '1'     | External enable. '1' = the scrubber runs in idle cycles. '0' suspends it on the same cycle: the FSM is held in `Idle_s`, the scrubber's read and writeback requests are gated low combinationally, and the address counter is **preserved** so coverage resumes from the same address when this is reasserted. Use it to pin the scrubber down during ECC error-injection tests. |

### Scrubber Status

The status outputs report the scrubber's _own_ reads and are valid only on the cycle _Scrub_Rd_Valid_ = '1'.

| Name            | In/Out | Length | Default | Description                                                  |
| :-------------- | :----- | :----- | ------- | :----------------------------------------------------------- |
| Scrub_Rd_Valid  | out    | 1      | N/A     | Pulses '1' on the cycle a scrubber-issued read returns from the decoder (one pulse per scrubber read, regardless of whether an error was detected). Qualifies _Scrub_Rd_EccSec_ / _Scrub_Rd_EccDed_; also used by the scrubber core to mask the user-facing _RdValid_. |
| Scrub_Rd_EccSec | out    | 1      | N/A     | SEC flag of the scrubber's own read. The scrubber writes this address back when it is '1' (and _Scrub_Rd_EccDed_ = '0'), unless a user access on the same cycle aborts the operation; the address is then retried (see [Opportunistic Scrubbing](#opportunistic-scrubbing)). |
| Scrub_Rd_EccDed | out    | 1      | N/A     | DED flag of the scrubber's own read. The scrubber **does not** write the cell back in this case (the corrected value is unreliable). |
| Scrub_PassDone  | out    | 1      | N/A     | Pulses '1' for one cycle when the scrubber's address counter rolls over from _Depth_g_-1 back to 0, marking a completed pass over the memory. |

## Detailed Description

### Architecture

![olo_ft_ram_sp_scrub architecture](./ram/olo_ft_ram_sp_scrub_arch.drawio.png)

The wrapper places the [olo_ft_private_scrubber](./olo_ft_private_scrubber.md) in front of the wrapped
[olo_ft_ram_sp](./olo_ft_ram_sp.md). The scrubber owns the user/scrubber arbitration: the single user port
(`Addr` / `WrEna` / `WrData` / `RdEna`) is tied to both of the scrubber's user channels, and the scrubber returns
muxed write and read RAM channels (`Ram_Wr_*` / `Ram_Rd_*`). It taps the RAM's decoded read output
(`Ram_RdData` / `Ram_RdEccSec` / `Ram_RdEccDed`) for its FSM and writeback payload. The user always wins; the scrubber
drives the RAM only on cycles where the user port is idle (`WrEna = RdEna = 0`).

Because the underlying RAM is single-port, the wrapper collapses the two RAM channels back onto the one physical port
with a single address mux (`Ram_Addr = Ram_Wr_Addr when Ram_Wr_Ena else Ram_Rd_Addr`); the write enable, write data
and read enable pass straight through. `ErrInj_*` go directly to the wrapped RAM's encoder, bypassing the scrubber.

The decoder's `RdData` / `RdEccSec` / `RdEccDed` are forwarded straight to the user; the two ECC flags are not masked,
so they also reflect scrubber-issued reads (qualify them with `RdValid`). The RAM's read-valid is fed into
the scrubber, which masks the cycles consumed by its own reads and returns the user-facing valid
(`User_Rd_Valid = Ram_RdValid AND NOT Scrub_Rd_Valid`); the wrapper forwards that directly to `RdValid`. The mask
lives in the scrubber core because its read-valid is already aligned to the decoder-return cycle by the internal
length-(`RamRdLatency_g` + `EccPipeline_g`) pipeline (see [olo_ft_private_scrubber](./olo_ft_private_scrubber.md)).

### Opportunistic Scrubbing

- **Single shared port.** Because the underlying RAM is single-port, the scrubber issues its read **and** its
  writeback only on cycles where the user is doing nothing (`WrEna = '0'` and `RdEna = '0'`). A continuously active
  user starves the scrubber but never causes data corruption.
- **Free-running.** There is no rate-limit generic; the scrubber advances as fast as user-idle cycles allow.
- **User always wins.** Any user access (or `Scrub_Enable = '0'`) raises `Scrub_Inhibit`, which aborts an in-flight
  scrub operation back to `Idle_s` without advancing the address counter and without writing back. The address is
  retried on the next idle slot, so user data is always authoritative.
- **SEC-only writeback.** Only correctable single-bit errors are rewritten. Clean cells are left untouched; a DED read
  is reported on `Scrub_Rd_EccDed` but never written back.

See [olo_ft_private_scrubber](./olo_ft_private_scrubber.md) for the scrubber FSM (states, abort behavior and read-valid
alignment).

### Pausing the Scrubber

`Scrub_Enable = '0'` holds the scrubber FSM in `Idle_s` and gates its read/writeback requests low combinationally
on the same cycle. The internal address counter is preserved, so the next `Scrub_Enable = '1'` resumes scrubbing from
the same address. This is the deterministic way to keep the scrubber from interacting with an injection-test sequence:

```vhdl
Scrub_Enable <= '0';
wait until rising_edge(Clk);     -- FSM held in Idle_s
ErrInj_BitFlip <= some_pattern;  -- preload the encoder's injection latch
ErrInj_Valid   <= '1';
wait until rising_edge(Clk);
ErrInj_Valid   <= '0';
... wait / set up / verify ...
WrEna  <= '1';                   -- the latched pattern lands on this write
WrData <= test_value;
wait until rising_edge(Clk);
WrEna  <= '0';
... read back, check RdEccSec = '1' ...
Scrub_Enable <= '1';             -- resume background scrubbing
```

### ECC Overhead, Error Injection and Status Flags

The ECC behavior is identical to the wrapped [olo_ft_ram_sp](./olo_ft_ram_sp.md), because it is the same instance. See
the corresponding sections in [Open Logic Fault-Tolerance Principles](./olo_ft_principles.md):

- [ECC Overhead](./olo_ft_principles.md#ecc-overhead) - internal storage width vs. data width
- [Error Injection](./olo_ft_principles.md#error-injection) - semantics of _ErrInj\_BitFlip_ / _ErrInj\_Valid_
- [Error Status Flags](./olo_ft_principles.md#error-status-flags) - meaning of _RdEccSec_ / _RdEccDed_

### Constraints

See
[Open Logic Fault-Tolerance Principles - Constraints That Apply Across the Area](./olo_ft_principles.md#constraints-that-apply-across-the-area)
for the no-byte-enables and no-initialization constraints. In addition, the scrubbing wrapper is **synchronous-only**:
the scrubber observes the user port on a single clock, so there is no async read clock. There is deliberately no scrub
variant of the true-dual-port RAM; see [olo_ft_private_scrubber](./olo_ft_private_scrubber.md#constraints) for the
rationale.
