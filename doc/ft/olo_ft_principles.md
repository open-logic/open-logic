<img src="../Logo.png" alt="Logo" width="400">

# Open Logic Fault-Tolerance Principles

[Back to **Entity List**](../EntityList.md)

This page collects the cross-cutting concepts that apply to every entity in the _ft_ (fault-tolerance) area.
Per-entity documentation links back here instead of duplicating the same material.

## Why Fault Tolerance?

Designs that operate in radiation-exposed environments (space, avionics, automotive, high-altitude) experience
single-event upsets (SEUs) — energetic particles flipping bits in storage elements. Memory cells are particularly
exposed because the stored charge representing each bit is small and the cell density is high.

The _ft_ area provides building blocks that detect and correct such bit flips transparently to the surrounding
design.

## SECDED Hamming Code

All ECC-protected entities in the _ft_ area use the same **SECDED** (Single Error Correction, Double Error
Detection) scheme: a standard Hamming code extended with one overall-parity bit. The encoding is implemented in
[olo_ft_pkg_ecc](./olo_ft_pkg_ecc.md).

### Codeword Layout

Codeword bit 0 is the overall parity bit. Bits at power-of-2 positions (1, 2, 4, 8, ...) within the Hamming code
are Hamming parity bits. Remaining positions hold the data bits. The codeword layout is identical for every entity
in the _ft_ area.

### ECC Overhead

The SECDED Hamming code adds parity bits to each stored word. The internal storage (RAM, FIFO buffer, ...) is
correspondingly wider:

| Data Width | Parity Bits | Total Stored Bits |
| :--------- | :---------- | :---------------- |
| 8          | 5           | 13                |
| 16         | 6           | 22                |
| 32         | 7           | 39                |
| 64         | 8           | 72                |
| 128        | 9           | 137               |

The "Parity Bits" column counts Hamming parity bits plus one overall-parity bit (the value reported by
[eccParityBits](./olo_ft_pkg_ecc.md#eccparitybits) is Hamming-only, _without_ the overall-parity bit).

## Error Injection

Every ECC-protected entity exposes a paired error-injection interface:

- _ErrInj_BitFlip_ (or _A_ErrInj_BitFlip_ / _B_ErrInj_BitFlip_ / _In_ErrInj_BitFlip_ on the sister entities)
  is the codeword-wide flip pattern. The port is
  [eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(_Width_g_) bits wide and is XORed into the encoded
  codeword before storage, so any single-bit or double-bit error pattern can be exercised.
- _ErrInj_Valid_ is a strobe. While '1', the current _ErrInj_BitFlip_ value is latched into an internal
  register. The latched pattern is applied to the next write and cleared after that write completes.

This decouples error injection from write timing. Preload the pattern any cycle, and it is applied to
the next user write whenever that happens. If _ErrInj_Valid_ = '1' and the write enable is also '1' in the
same cycle, the pattern is applied immediately without going through the latch.

| Popcount of injection | Meaning              | Behavior                                                                                 |
| :-------------------- | :------------------- | :--------------------------------------------------------------------------------------- |
| 0                     | No injection         | Codeword stored unchanged. SEC flag = '0', DED flag = '0'.                               |
| 1                     | Single-bit error     | SEC-correctable. SEC flag = '1', DED flag = '0', data corrected.                         |
| 2                     | Double-bit error     | DED-detectable. SEC flag = '0', DED flag = '1', data unreliable.                         |
| >= 3                  | Outside SECDED range | Detection behavior is undefined - the SECDED Hamming code only guarantees correct classification for at most 2 bit errors. |

## Error Status Flags

Every ECC-protected entity drives two status outputs (named _*EccSec_ / _*EccDed_, with prefixes matching the data
port — for example _RdEccSec_ / _RdEccDed_ on a single-port RAM):

- **EccSec ('1')**: a single-bit error was detected and the data output has already been corrected.
- **EccDed ('1')**: a double-bit error was detected. The data output is unreliable in this case; the surrounding
  design must decide whether to retry, raise an alarm, or escalate to a system-level recovery.

The flags are time-aligned with the corresponding data word.

## ECC Pipeline (`EccPipeline_g`)

Every ECC-protected entity exposes an `EccPipeline_g : natural := 0` generic that inserts register stages after
the ECC decode combinational logic.

- `0` (default): the decoded data and the SEC/DED flags are combinational on the read path.
- `>= 1`: register stages are inserted between the decoder and the output. This breaks the combinational path
  between the storage element and the corrected data output, helping close timing at high clock frequencies.

Total read latency from address-presented to data-valid is therefore `RamRdLatency_g + EccPipeline_g` cycles for
RAM-based entities. FIFO-based entities expose a corresponding read-side latency: see the per-entity doc.

## Instantiation from Verilog and VHDL

The SECDED encode and decode logic is also exposed as standalone entities -
[olo_ft_ecc_encode](./olo_ft_ecc_encode.md) and [olo_ft_ecc_decode](./olo_ft_ecc_decode.md) - so that Verilog
designs (which cannot call functions from a VHDL package) can use them directly. The package functions in
[olo_ft_pkg_ecc](./olo_ft_pkg_ecc.md) remain the cleanest interface for VHDL designs but the entities are
fully equivalent and shared by every ECC-protected entity in the area to avoid duplicating the codec body.

Use cases beyond RAM/FIFO protection:

- Forward error correction over a transmission link.
- AXI4-Stream traffic that is buffered in unprotected external memory (encode at the producer, decode at the
  consumer).

## Read-Data Valid

Every ECC-protected RAM exposes a read-data-valid output (named _RdValid_, _Rd_Valid_ or _A_RdValid_/_B_RdValid_
depending on the entity). It pulses '1' on the exact cycle when the matching _RdData_, _SEC_ and _DED_ outputs
correspond to a read the user issued, i.e. it is the read-enable delayed by `RamRdLatency_g + EccPipeline_g`.

For RAMs with a scrubber (`olo_ft_ram_sp_scrub`, `olo_ft_ram_sdp_scrub`), the valid signal is gated so that cycles
consumed by the scrubber do not pulse on the user-facing valid line.

FIFO-based entities use the standard AXI4-Stream `Out_Valid` signal for the same purpose; no separate
`*RdValid` port is needed.

## Constraints That Apply Across the Area

- **No byte enables.** ECC covers the full word; a partial write would invalidate the parity bits.
- **No memory initialization.** Internal storage holds codewords, not raw data, so initialization values would
  need to be pre-encoded — not supported.
- **Time-alignment is hard guaranteed.** The SEC/DED flags are always issued in the same cycle as the
  corresponding data output, regardless of `EccPipeline_g`.
