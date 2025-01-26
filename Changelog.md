<img src="./doc/Logo.png" alt="Logo" width="400">

# Changelog

## 3.1.0

27-Jan-2025

### Added Features

- Support for Gowin toolchain
  - Synthesis attributes
  - Script to import Open Logic
  - Tutorial

- Added more functions to _olo_base_pkg_logic_
  - Added _invertByteOrder()_
  - Added _greatestCommonFactor()_
  - Added _leastCommonMultiple()_

- Added _olo_base_wconv_m2n_
  - Arbitrary width converter (any input width to any output width)

- Added _olo_base_crc_
  - CRC calculation engine
  - Can calculate multiple input bits per clock cycle

### Backward Compatible Changes

- Timing optimization for _olo_base_fifo_async_
  - General timing optimization to reach higher clock frequencies
  - Added generic to select between optimization for latency or speed
  - Reported by: [svancau](https://github.com/svancau)

- Improved FuseSoC setup (#109)
  - Users can choose between local files or official releases
  - _open-logic:open-logic:..._ for  official release (downloaded from GitHub)
  - _open-logic:open-logic-dev:..._ for local files
  - Reported by: [rbrglez](https://github.com/rbrglez)

- Extracted attributes used by Open Logic into _olo_base_pkg_attribute_

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- None

### Reporters

- [svancau](https://github.com/svancau)
- [rbrglez](https://github.com/rbrglez)

### Contributors

- None

## 3.0.2

01-Dec-2024

### Added Features

- None

### Backward Compatible Changes

- Added synchronous assertion to _olo_base_reset_gen_ (#101)
  - Synchronous assertion is used for _AsyncResetOutput_g_=true

  - Number of synchronization stages is configurable through SyncStages_g

  - Reported by: [tasgomes](https://github.com/tasgomes)

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fix reset CDC in _olo_intf_clk_meas_ (#99)
  - Added proper reset CDC from _Clk_ to _ClkMeas_
  - Reported by: [tasgomes](https://github.com/tasgomes)

### Reporters

- [tasgomes](https://github.com/tasgomes)

### Contributors

- None

## 3.0.1

26-Nov-2024

### Added Features

- Addition of Markdown linter to ensure adherence to markdown conventions (#93)
  - See [Conventions](./doc/Conventions.md#documentation) for documentation about how to use it
  - Co-authored by: [gckoeppel](https://github.com/gckoeppel)

### Backward Compatible Changes

- Various documentation improvements
  - Some of them contribured by: [gckoeppel](https://github.com/gckoeppel), [Monish-VR](https://github.com/Monish-VR)

- Improve linter configuration
  - Workaround for procedures and functions without arguments was removed

- Improvements on VSCode integration

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fix _olo_axi_master_simple_ for _AxiAddrWidth_g_ < log2(_AxiMaxBeats_g_+1) (#87)
  - Reported by: [daielkraak](https://github.com/daielkraak)

### Reporters

- [daielkraak](https://github.com/daielkraak)
- [gckoeppel](https://github.com/gckoeppel)

### Contributors

- [gckoeppel](https://github.com/gckoeppel)
- [Monish-VR](https://github.com/Monish-VR)

## 3.0.0

28-Oct-2024

### Added Features

- Microchip Libero integration
  - Script to automatically import all _Open Logic_ features into a _Libero_ project
  - _Libero_ tutorial (see [LiberoTutorial](./doc/tutorials/LiberoTutorial.md))
- Addition of VSG linter to ensure adherence to coding conventions (#43)
  - See [HowTo](./doc/HowTo.md) for documentation about how to use it
  - Co-authored by: [patrick-studer](https://github.com/patrick-studer)

- VSCode integration of VSG linter and VUnit simulation
  - See [HowTo](./doc/HowTo.md) for documentation about how to use it

- Extension of CI workflow
  - Addition of VSG linting
  - Addition of job to aggregate all results and report them in the GitHub Pull-Request

### Backward Compatible Changes

- Various documentation improvements
- Addition of generic to configure number of synchronization stages in all clock-crossings.
  This allows satisfying very high MTBF requirements.
  - Modified entities: _olo_base_cc_..._ and _olo_base_fifo_async_

### Non Backward Compatible Changes

All entities are backward compatible. Non backward compatible changes were applied to packages only.

- Modifications to packages to follow coding conventions.
  - Affected entities: _olo_base_pkg_array, , _olo_axi_pkg_protocol_, _olo_intf_i2c_master_pkg_

- Removal of reducing logic functions from _olo_base_pkg_logic_ (#85)
  - The reducing logic functions from _ieee.std_logic_misc_ shall be used instead
  - Reported by: [andkae](https://github.com/andkae)

### Bugfixes (Backward Compatible)

- Fix heap-size issue for NVC simulator

### Reporters

- [andkae](https://github.com/andkae)
- [tasgomes](https://github.com/tasgomes)

### Contributors

- [patrick-studer](https://github.com/patrick-studer)

## 2.3.1

16-Oct-2024

### Added Features

- None

### Backward Compatible Changes

- None

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- **CRITICAL** - Fix wrong clock crossing in _olo_base_fifo_async_ (#79)
  - Reported by: [aleschx](https://github.com/aleschx)

### Reporters

- [aleschx](https://github.com/aleschx)
- [tasgomes](https://github.com/tasgomes)

### Contributors

- None

## 2.3.0

27-Sep-2024

### Added Features

- Implement synthesis attributes for Synplify based tools
  - Examples of Synplify based toolchains: Lattice ICECube, Microchip

- Setup of Github Sponsors profile for funding the project
- _olo_base_packet_fifo_
  - Store and forward packet FIFO
  - Allows to drop packets while writing them (even after some data was written)
  - Allows skipping and repeating packets when reading them

- _olo_intf_uart_
  - UART interface

- _olo_base_decode_firstbit_
  - Timing optimal first-bit decoder

- _olo_base_cam_
  - Content addressable memory

- _olo_base_strobe_gen_
  - Added fractional mode - dynamically extend/shorten period by one clock cycle to meet the requested average
    strobe frequency.

### Backward Compatible Changes

- Various documentation improvements
- _olo_intf_spi_slave_
  - Suppress needless MISO toggling at the end of a transaction (#68, reported by
    [betocool-prog](https://github.com/betocool-prog) )

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fixed documentation of _olo_intf_spi_slave_.
  - Maximum SCLK frequency is 8x lower than Clk frequency (not 6x)

### Credits

#### Reporters

- [betocool-prog](https://github.com/betocool-prog)

#### Contributors

- None

## 2.2.0

04-Sep-2024

### Added Features

- Support for NVC Simulator
  - NVC simulator can be started passing the argument "--nvc" to the run.py
  - Added NVC simulator to CI scripts
  - Co-authored by nickg
- Questa integration
  - Script to automatically compile all _Open Logic_ features in _Questa_
  - _Questa_ tutorial (VHDL and Verilog)
- Addition of _to01()_ functions to _olo_base_pkg_logic_
- _olo_intf_spi_slave_
  - SPI slave
- _olo_base_cc_handshake_
  - Clock crossing with fully Read/Valid handshake but without need for distributed RAM (in contrast to
    _olo_base_fifo_async_)

### Backward Compatible Changes

- Various documentation improvements
  - Clarification regarding omission of ID signals in _olo_axi_master_..._ (#50, contributed by
    [kuriousd](https://github.com/kuriousd) )
  - Remove duplicated _Ready_ signal from figures in Conventions (#54, reported by
    [tasgomes](https://github.com/tasgomes) )
- Various optimizations on the CI/CD infrastructure
- Reduction of the latency of _olo_base_cc_pulse_ by one clock cycle

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- None

### Credits

#### Reporters

- [tasgomes](https://github.com/tasgomes)

#### Contributors

- [nickg](https://github.com/nickg)
- [kuriousd](https://github.com/kuriousd)

## 2.1.0

30-Jul-2024

### Added Features

- Efinix Efinity integration
  - Script to automatically import all _Open Logic_ features into an _Efinity_ project
  - Addition of synthesis attributes for _Efinity_
  - _Efinity_ tutorial
- Added _FuseSoC_ package manager support
- _olo_intf_spi_master_
  - SPI master

### Backward Compatible Changes

- Various documentation improvements
- Various optimizations on the CI/CD infrastructure

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fixed sensitivity list in _olo_axi_master_simple_ (#41)
  - _M_Axi_RResp_ was missing
  - Credits to [kuriousd](https://github.com/kuriousd) for reporting
- Process scoped constraints _late_ for AMD Vivado
  - User constraints must be processed before scoped constraints, otherwise clocks are not known to scoped constraints

## Credits

### Reporters

- [kuriousd](https://github.com/kuriousd)

### Contributors

- None

## 2.0.0

06-Jul-2024

### Added Features

- Altera Quartus integration
  - Script to automatically import all _Open Logic_ features into a Quartus project
- Added tutorials
  - Vivado Verilog tutorial
  - Quartus VHDL tutorial
  - Quartus Verilog tutorial
- _olo_base_reset_gen_
  - Reset generator (and synchronizer)
- _olo_base_flowctrl_handler_
  - Allows to add flow-control (ready) around entities without flow-control (valid only)

### Backward Compatible Changes

- Various documentation improvements

### Non Backward Compatible Changes

- Removed _t_aslv_ (array of unconstrained std_logic_vector) from _olo_base_pkg_array_
  - Arrays of unconstrained types are not accepted by Quartus

### Bugfixes (Backward Compatible)

- None

## 1.2.0

27-Jun-2024

### Added Features

- AMD Vivado integration
  - Script to automatically import all _Open Logic_ features into a Vivado project
  - Vivado tutorial
- _olo_intf_clk_meas_
  - Measure the frequency of a clock signal (based on a clock with a known frequency)
- _olo_intf_debounce_
  - Debouncing for external signals (e.g. inputs from switches or buttons)

### Backward Compatible Changes

- Various documentation improvements
- Execute scoped constraint scripts in separate namespaces
  - This avoids unwanted interactions between the script through global variables

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fix scoped constraints for _olo_intf_sync_
  - Incomplete input delays were reported before the fix
- Fix inconsistencies of _olo_intf_i2c_master_ generic default values compared to documentation
  - There was a mismatch for _CmdTimeout_g_
  - _ClkFrequency_g_ had a default value in the implementation before the change (which is wrong because the clock is
    specific to the design)

## 1.1.0

15-Jun-2024

### Added Features

- _olo_intf_i2c_master_
  - I2C master
  - Multi-Master and clock-stretching capable
- _olo_intf_sync_
  - Double stage synchronizer for asynchronous external signals
  - Includes scoped timing constraints
- _olo_axi_master_full_
  - AXI Master with support for unaligned and odd-sized transfers (other sizes than multiple of AXI words)

### Backward Compatible Changes

- Various documentation improvements
- Added _Rd_Last_ signal to _olo_axi_master_simple_ to simplify handling of read-data.
- _olo_base_wconv_n2xn_ now supports InWidth=OutWidth

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Change default _UserTransactionSizeBits_g_ in _olo_axi_master_simple_ to 24 bits
  - The combination of default values before was illegal
  - Backwards compatible because the default values had to be overwritten for successful compilation before the change
    anyways.
- Change default values of _AlmFullLevel_g_ and _AlmEmptyLevel_g_ to 0
  - Using another generic (_Depth_g_) as default value for generics is illegal.
  - Backwards compatible because the default values had to be overwritten for successful compilation before the change
    anyways.
- Fix _AxiDataWidth_g_ related assertions in _olo_axi_lite_slave_
  - Backwards compatible because the change only adds error messages for anyways illegal generics combinations

## 1.0.0

31-May-2024

First release

### Added Features

n/a

### Backward Compatible Changes

n/a

### Non Backward Compatible Changes

n/a

### Bugfixes (Backward Compatible)

n/a

## 0.x.x

All 0.x.x releases are considered early stage development and not documented in detail.
