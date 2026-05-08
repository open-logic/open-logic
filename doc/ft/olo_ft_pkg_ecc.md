<img src="../Logo.png" alt="Logo" width="400">

# olo_ft_pkg_ecc

[Back to **Entity List**](../EntityList.md)

## Status Information

VHDL Source: [olo_ft_pkg_ecc](../../src/ft/vhdl/olo_ft_pkg_ecc.vhd)

## Description

This package contains SECDED (Single Error Correction, Double Error Detection) Hamming code functions used internally
by the ECC-protected entities in the _ft_ area (e.g. [olo_ft_ram_sp](./olo_ft_ram_sp.md)).

All functions in this package are synthesizable; there are no testbench-only helpers. They split into two
categories:

- **Elaboration-time helpers** — [eccParityBits](#eccparitybits) and [eccCodewordWidth](#ecccodewordwidth) are
  pure integer functions of a `positive` argument. Their typical use is to size ports and signals from a generic
  data width (e.g. `signal Codeword : std_logic_vector(eccCodewordWidth(Width_g) - 1 downto 0);`). They evaluate to
  a constant at elaboration and produce no logic.
- **Combinational RTL logic** — [eccEncode](#eccencode), [eccSyndromeAndParity](#eccsyndromeandparity),
  [eccCorrectData](#ecccorrectdata), [eccSecError](#eccsecerror) and [eccDedError](#eccdederror) operate on
  signals in the read/write datapath. They synthesize to combinational logic (XOR trees and selection).

The encoding uses a standard Hamming code with an additional overall parity bit for double error detection. Resulting overhead:

| Data Width | Parity Bits | Total Stored Bits |
| :--------- | :---------- | :---------------- |
| 8          | 5           | 13                |
| 16         | 6           | 22                |
| 32         | 7           | 39                |
| 64         | 8           | 72                |
| 128        | 9           | 137               |

## Functions

### eccParityBits

```vhdl
function eccParityBits (
    DataWidth : positive
) return positive;
```

Returns the number of Hamming parity bits required for a given data width (excluding the overall parity bit). Computed
as the smallest _m_ such that _2^m >= DataWidth + m + 1_.

**Usage:** Synthesizable, elaboration-time helper. Typical use is to size signals/ports from a generic.

### eccCodewordWidth

```vhdl
function eccCodewordWidth (
    DataWidth : positive
) return positive;
```

Returns the total codeword width including data bits, Hamming parity bits, and the overall parity bit. Equivalent to
_DataWidth + eccParityBits(DataWidth) + 1_.

**Usage:** Synthesizable, elaboration-time helper. Typical use is to size signals/ports from a generic.

### eccEncode

```vhdl
function eccEncode (
    Data : std_logic_vector
) return std_logic_vector;
```

Encodes a data word into a SECDED codeword. Bit 0 of the result is the overall parity bit; bits at power-of-2 positions
(1, 2, 4, 8, ...) are Hamming parity bits; remaining positions hold the data bits.

**Usage:** Synthesizable, combinational. Used on the write path to produce the codeword stored in memory.

### eccSyndromeAndParity

```vhdl
function eccSyndromeAndParity (
    Codeword  : std_logic_vector;
    DataWidth : positive
) return std_logic_vector;
```

Computes the syndrome and overall parity from a (possibly corrupted) codeword. The result packs both into one vector:
bits _ParityBits-1 downto 0_ hold the syndrome, bit _ParityBits_ holds the overall parity error. Result intended to be
fed into [eccCorrectData](#ecccorrectdata), [eccSecError](#eccsecerror), and [eccDedError](#eccdederror).

**Usage:** Synthesizable, combinational. Used on the read path before the optional ECC pipeline registers.

### eccCorrectData

```vhdl
function eccCorrectData (
    Codeword  : std_logic_vector;
    SynPar    : std_logic_vector;
    DataWidth : positive
) return std_logic_vector;
```

Extracts the corrected data bits from a codeword using the precomputed syndrome/parity from
[eccSyndromeAndParity](#eccsyndromeandparity). When a single-bit error is detected (overall parity odd, syndrome
nonzero), the offending bit is corrected before extraction.

**Usage:** Synthesizable, combinational. Used on the read path to drive the corrected data output.

### eccSecError

```vhdl
function eccSecError (
    SynPar : std_logic_vector
) return std_logic;
```

Returns '1' when a single-bit error was corrected. Under SECDED assumption (at most two bit errors per codeword), an
odd overall parity bit indicates a single-bit error.

**Usage:** Synthesizable, combinational. Drives the SEC status output.

### eccDedError

```vhdl
function eccDedError (
    SynPar : std_logic_vector
) return std_logic;
```

Returns '1' when a double-bit error was detected. A nonzero syndrome combined with even overall parity indicates two
bit errors, which SECDED can detect but not correct.

**Usage:** Synthesizable, combinational. Drives the DED status output.
