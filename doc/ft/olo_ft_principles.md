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

Every ECC-protected entity exposes the same paired error-injection interface: _ErrInj\_BitFlip_ and
_ErrInj\_Valid_. The latch lives inside the codec entity, so RAM/FIFO wrappers simply forward the
strobes.

- The _ErrInj\_BitFlip_ port is the codeword-wide flip pattern. It is
  [eccCodewordWidth](./olo_ft_pkg_ecc.md#ecccodewordwidth)(_Width_g_) bits wide and XORed into the
  codeword. For [olo_ft_ecc_encode](./olo_ft_ecc_encode.md) (and the RAM/FIFO write side) the XOR happens
  after encoding. For [olo_ft_ecc_decode](./olo_ft_ecc_decode.md) the XOR happens before the syndrome
  calculation, so it simulates a corruption that occurred between the encoder and the decoder.
- The _ErrInj\_Valid_ strobe latches the current _ErrInj\_BitFlip_ value into an internal register.
  The latched pattern is applied to the next accepted beat (write side) or codeword (read side) and
  is cleared once that beat completes the handshake.

This decouples error injection from data timing. Preload the pattern any cycle, and it is applied to
the next data beat whenever that happens. If _Valid_ = '1' and the handshake completes in the same cycle,
the pattern is applied directly without going through the latch.

The latch is cleared by _Rst_, so an injection request issued before reset cannot leak into post-reset
operation.

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

## Codec Entities

The SECDED encode and decode logic is exposed as standalone entities:
[olo_ft_ecc_encode](./olo_ft_ecc_encode.md) and [olo_ft_ecc_decode](./olo_ft_ecc_decode.md), which make use of
the package functions provided in [olo_ft_pkg_ecc](./olo_ft_pkg_ecc.md).

Both entities provide an AXI4-Stream handshake (_In\_Valid_ / _In\_Ready_, _Out\_Valid_ /
_Out\_Ready_). Back-pressure is honoured by default (`UseReady_g => true`); set `UseReady_g => false` for
register-chain instantiations that never need back-pressure.

Use cases beyond RAM/FIFO protection:

- Forward error correction over a transmission link.
- AXI4-Stream traffic that is buffered in unprotected external memory (encode at the producer, decode at the
  consumer).

## Read-Data Valid

Every ECC-protected RAM exposes a read-data-valid output (`RdValid`). It pulses '1' on the exact cycle when the
matching `RdData`, `SEC` and `DED` outputs correspond to a read the user issued, i.e. it is the read-enable
delayed by `RamRdLatency_g + EccPipeline_g`.

## Constraints That Apply Across the Area

- **No byte enables.** ECC covers the full word; a partial write would invalidate the parity bits.
- **No memory initialization.** Internal storage holds codewords, not raw data, so initialization values would
  need to be pre-encoded — not supported.
- **Time-alignment is hard guaranteed.** The SEC/DED flags are always issued in the same cycle as the
  corresponding data output, regardless of `EccPipeline_g`.
