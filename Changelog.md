<img src="./doc/Logo.png" alt="Logo" width="400">

# Changelog

## 4.4.1

10-Mar-2026

### Added Features

- Added _fixDynShift()_ function to _olo_fix_pkg_
  - Dynamically shift a fixed-point number by a variable amount of bits
  - Contributed by: [obruendl](https://github.com/obruendl)

### Backward Compatible Changes

- None

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- MAke CORDIC (rotation and vecotring) synthesizable in Mode_g=Serial
  - Affected entities: _olo_fix_cordic_rot_, _olo_fix_cordic_vect_
  - The entities did fail synthesis with the setting Mode_g=Serial
  - Reported by: [Niv Cohen](https://github.com/niv-cohen-ks)

### Reporters

- [Niv Cohen](https://github.com/niv-cohen-ks)

### Contributors

- [obruendl](https://github.com/obruendl)

## 4.4.0

28-Feb-2026

### Added Features

- Added _log2ceil()_ function for real values to _olo_base_pkg_math_
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_fix_cic_dec_tdm_
  - CIC decimator with time-division multiplexed input and output
  - Supports one or multiple channels
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_fix_cic_dec_par_tdm_
  - CIC decimator with parallel input and time-division multiplexed output
  - Supports one or multiple channels
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_fix_pkg_writer_
  - Python script to automatically generate VHDL packages and verilog headers to contain data from python
  - Used to pass parameters and number formats for fixed-point processing from Python to HDL
  - Contributed by: [obruendl](https://github.com/obruendl)

### Backward Compatible Changes

- Update tools in CI Pipeline
  - Python 3.10 -> Python 3.13
  - GHDL 3.0.0 -> GHDL 4.1.0
  - NVC 1.13.3  -> NVC 1.19.0
  - VUnit 4.7.0 -> VUnit 5.0.0.dev7

- Make all string generics case-insensitive
  - Contributed by: [obruendl](https://github.com/obruendl)

- Allow _InWidth_g=_OutWidth_g_ in _olo_base_wconv_n2xn_
  - Contributed by: [obruendl](https://github.com/obruendl)

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fix TX hanshaking issue in _olo_intf_spi_slave_
  - When _Tx_Valid_ was asserted after _Tx_Ready_ data was wrongly transferred
  - Reported by: [borjarevuelta-tec](https://github.com/borjarevuelta-tec)

### Reporters

- [borjarevuelta-tec](https://github.com/borjarevuelta-tec)

### Contributors

- [obruendl](https://github.com/obruendl)

## 4.3.0

25-Jan-2026

### Added Features

- Added _olo_fix_cordic_rot_ and _olo_fix_cordic_vect_
  - CORDIC algorithm for rotation and vectoring
  - Supports pipelined and serial modes
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_fix_bin_div_
  - Binary divider for fixed-point numbers
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_base_latency_comp_
  - Latency compensation component
  - Contributed by: [obruendl](https://github.com/obruendl)

### Backward Compatible Changes

- Various documentation improvements

- Initialization improvement for _olo_base_cc_reset_
  - Use reset value as initial value to improve synthesis on Altera Arria 10
  - Contributed by: [LukiLeu](https://github.com/LukiLeu)

- Improved resource control by adding more generics to _olo_base_delay_ and _olo_base_delay_cfg_
  - Contributed by: [obruendl](https://github.com/obruendl)

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- None

### Reporters

- None

### Contributors

- [obruendl](https://github.com/obruendl)
- [LukiLeu](https://github.com/LukiLeu)

## 4.2.0

09-Dec-2025

### Added Features

- Support for Yosys toolchain
  - Synthesis attributes
  - Addition of Yosys Cologne Chip synthesis to CI workflows
  - Script to import Open Logic

- Support for Cologne Chip FPGAs
  - Yosys support (see above)
  - Addition of Cologne Chip synthesis to CI workflows
  - Tutorial

- Added _olo_base_rate_limit_
  - Contributed by: [obruendl](https://github.com/obruendl)

### Backward Compatible Changes

- Various documentation improvements
  - Some of them reported by: [rickhg12hs](https://github.com/rickhg12hs),
  [fpgauserdude](https://github.com/fpgauserdude)

- Improvement of scoped constraints (Vivado) for _olo_intf_sync_
  - Contributed by: [tasgomes](https://github.com/tasgomes)

- Add optional byte-enables to _olo_base_crc_
  - Contributed by: [rbrglez](https://github.com/rbrglez)

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fix scooped constraints (Vivado) for olo_base_ram_sdp when implemented with distributed RAM
  - Affected entities: _olo_base_ram_sdp_
  - Contributed by: [LukiLeu](https://github.com/LukiLeu), [tasgomes](https://github.com/tasgomes)

- Fix half-bit-slip in _olo_intf_uart_ depending on exact bit timing
  - Affected entities: _olo_intf_uart_
  - Reported by: [jonpovey](https://github.com/jonpovey)

### Reporters

- [rickhg12hs](https://github.com/rickhg12hs)
- [fpgauserdude](https://github.com/fpgauserdude)
- [jonpovey](https://github.com/jonpovey)

### Contributors

- [obruendl](https://github.com/obruendl)
- [rbrglez](https://github.com/rbrglez)
- [tasgomes](https://github.com/tasgomes)
- [LukiLeu](https://github.com/LukiLeu)

## 4.1.0

13-Sep-2025

### Added Features

- Added scoped constraints for _olo_base_ram_sdp_ to avoid timing violations being reported for
  implementation with distributed RAM
  - Contributed by: [tasgomes](https://github.com/tasgomes)

- Added getSetBitIndex(), getLeadingSetBitIndex() and getTrailingSetBitIndex() functions to
  _olo_base_pkg_logic_ for detecting first/last set bit in a std_logic_vector
  - Contributed by: [rbrglez](https://github.com/rbrglez)
  
- Added _olo_base_arb_wrr_ Weighted Round Robin Arbiter
  - Contributed by: [rbrglez](https://github.com/rbrglez)

- Added runtime SCL frequency selection to _olo_intf_i2c_master_
  - Contributed by: [aruede](https://github.com/aruede)

- Added _DROP_ONLY_ mode to _olo_base_fifo_packet_
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_base_crc_append_
  - Contributed by: [obruendl](https://github.com/obruendl)

- Added _olo_base_crc_check_
  - Contributed by: [obruendl](https://github.com/obruendl)

### Backward Compatible Changes

- Various documentation improvements
  - Some of them reported by: [rbrglez](https://github.com/rbrglez), [JimLewis](https://github.com/JimLewis),
    [paebbels](https://github.com/paebbels)

- Update to latest _en_cl_fix_ content available from [en_cl_fix](https://github.com/enclustra/en_cl_fix)

- CI synthesis now also checks if there are any latches
  - Contributed by: [obruendl](https://github.com/obruendl)

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fix default value of _Out_RstIn_  in _olo_base_cc_status_
  - Affected entities: _olo_base_cc_status_
  - Contributed by: [AndrzejKowalski9917](https://github.com/AndrzejKowalski9917)

- Make AXI verification components multi-instance capable
  - Affected entities: _olo_test_axi_master_vc_, _olo_test_axi_slave_vc_
  - Contributed by: [LukiLeu](https://github.com/LukiLeu)

- Fix linter errors on Windows PCs
  - Reported by: [LukiLeu](https://github.com/LukiLeu)

### Reporters

- [LukiLeu](https://github.com/LukiLeu)
- [JimLewis](https://github.com/JimLewis)
- [paebbels](https://github.com/paebbels)

### Contributors

- [obruendl](https://github.com/obruendl)
- [rbrglez](https://github.com/rbrglez)
- [LukiLeu](https://github.com/LukiLeu)
- [aruede](https://github.com/aruede)
- [tasgomes](https://github.com/tasgomes)
- [AndrzejKowalski9917](https://github.com/AndrzejKowalski9917)

## 4.0.0

26-Jun-2025

### Notes

Because the change to VHDL-2008 is non-reverse-compatible anyways, it was decided to put all pending
non-reverse-compatible changes into 4.0.0. As a result no breaking changes are foreseen in near future after 4.0.0.

### Added Features

- Added scoped constraints for Vivado to _FuseSoC_ packages.
  - Contributed by: [rbrglez](https://github.com/rbrglez)

- Added [compile_order.txt](./compile_order.txt) file to support compilation with any tool.
  - Input from the presentation at FDF25 at CERN

- CI workflow to execute synthesis for every entity in Open Logic

### Backward Compatible Changes

- Various documentation improvements
  - Some of them reported by: [tasgomes](https://github.com/tasgomes)
  - Some of them contributed by: [rbrglez](https://github.com/rbrglez), [LukiLeu](https://github.com/LukiLeu)
- Various smaller changes to the CI workflows

### Non Backward Compatible Changes

- Change language standard to VHDL-2008
  - All entities now must be compiled as VHDL-2008
  - Tool integrations are updated accordingly and will import Open Logic as VHDL-2008
  - Suggested action: Remove Open Logic from your project and re-add it using the tool integration scripts provided,
    see [HowTo](./doc/HowTo.md)

- Changed default generic values for _olo_fix_round_ and _olo_fix_saturate_ to round and saturate by default.
  - Affected entities: _olo_fix_round_, _olo_fix_saturate_
  - Reason: Instantiating those entities for NOT executing the corresponding operation (as it was the default before)
    does not make much sense.

- Remove unused generics
  - _olo_base_cam_ - removed _RamBlockWidth_g_
  - _olo_base_prbs_ - removed deprecated _LfsrWidth_g_
  - _olo_base_crc_ - removed _CrcWidth_g_
  - Reason: Code cleanup

- Harmonized polynomial handling between _olo_base_prbs_ and _olo_base_crc_
  - Affected entities: _olo_base_crc_
  - _Polynomial_g_, _InitialValue_g_ and _XorOutput_g_ are now _std_logic_vector_ instead of _natural_
  - Reason: _std_logic_vector_ allows for values wider than 32 bits. Using the same interface types for _olo_base_crc_
    and _olo_base_prbs_ is easier to understand for users.

- Change default value for _UserTransactionSizeBits_g_ from 32 to 24 in _olo_axi_master_full_
  - Affected entities: _olo_axi_master_full_
  - Reason: Default values for _UserTransactionSizeBits_g_ and _AxiAddrWidth_g_ were incompatible (led to assertion
    failures)

### Bugfixes (Backward Compatible)

- Fix _olo_base_delay_cfg_ for power of 2 _MaxDelay_g_ values
  - Affected entities: _olo_base_delay_cfg_

- Remove default values 'Z' from _olo_intf_i2c_master_ ports because this led to synthesis errors with
  _Microchip Libero_
  - Affected entities: _olo_intf_i2c_master_

- Removed _In_Real_ port  from _olo_fix_from_real_ because not all tools accept it for synthesis, even if unused.
  - Affected entities: __olo_fix_from_real_

- Fix needless _olo_base_strobe_gen_ number range error and document rate limitations. Ranges are now actively checked
  by assertions.
  - Affected entities: __olo_base_strobe_gen_
  - Reported by: [fpgauserdude](https://github.com/fpgauserdude)

### Reporters

- [fpgauserdude](https://github.com/fpgauserdude)
- [tasgomes](https://github.com/tasgomes)

### Contributors

- [rbrglez](https://github.com/rbrglez)
- [LukiLeu](https://github.com/LukiLeu)

## 3.3.0

04-May-2025

### Added Features

- Various documentation improvements
- Added fixed-point mathematics support based on [en_cl_fix](https://github.com/enclustra/en_cl_fix)
  - Includes bit-true python models
  - Includes a [tutorial](./doc/tutorials/OloFixTutorial.md) for the fixed-point development flow
  - Entities added: _olo_fix_abs, olo_fix_add, olo_fix_addsub, olo_fix_compare, olo_fix_from_real, olo_fix_limit,_
    _olo_fix_mult, olo_fix_neg, olo_fix_pkg, olo_fix_resize, olo_fix_round, olo_fix_saturate, olo_fix_sim_checker,_
    _olo_fix_sim_stimuli, olo_fix_sub, olo_fix_to_real_

- Added AWS CI runner for synthesis
  - Executes reference design test builds
  - Executes fusesoc test builds

- Added support for VHDL_LS
  - Automatic generation of TOML file (see [HowTo](./doc/HowTo.md))
  - Allows advanced code-browsing in VSCode

### Backward Compatible Changes

- None

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- None

### Reporters

- [the-oeni](https://github.com/the-oeni)

### Contributors

- None

## 3.2.0

01-Apr-2025

### Added Features

- Added option to initialize RAM
  - Affected entities: _olo_base_ram_tdp_, _olo_base_ram_sdp_ and _olo_base_ram_sp_

### Backward Compatible Changes

- Various documentation improvements
  - Some of them reported by: [tasgomes](https://github.com/tasgomes), [rbrglez](https://github.com/rbrglez),
    [peteut](https://github.com/peteut), [rbrglez](https://github.com/rbrglez)
- Removal of various needless declarations
  - Contributed by: [the-oeni](https://github.com/the-oeni)

- Allow symbols width bigger than LFSR width in _olo_base_prbs_
  - Co-authored by: [hh44bbbbyy](https://github.com/hh44bbbbyy)

### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fixed RAM inference with byte-enables for Quartus Prime Standard

  - Affected entities: _olo_base_ram_tdp_, _olo_base_ram_sdp_ and _olo_base_ram_sp_

- Fixed RAM inference for Gowin EDA:

  - Affected entities: _olo_base_ram_tdp_

- Fixed wrong wrong positive for assertions in _olo_axi_master_simple_

  - Only the assertion was changed, no synthesis relevant code was modified

  - Affected entites: _olo_axi_master_simple_, _olo_axi_master_full_

    Rreported by: [rbrglez](https://github.com/rbrglez)

### Reporters

- [tasgomes](https://github.com/tasgomes)
- [rbrglez](https://github.com/rbrglez)
- [peteut](https://github.com/peteut)
- [rbrglez](https://github.com/rbrglez)

### Contributors

- [the-oeni](https://github.com/the-oeni)
- [hh44bbbbyy](https://github.com/hh44bbbbyy)

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
