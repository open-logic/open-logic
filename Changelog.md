<img src="./doc/Logo.png" alt="Logo" width="400">

# Changelog

## 3.0.0

28-Oct-2024

### Added Features

- Microchip Libero integration
  * Script to automatically import all *Open Logic* features into a *Libero* project
  * *Libero* tutorial (see [LiberoTutorial](./doc/tutorials/LiberoTutorial.md))
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
- Addition of generic to configure number of synchronization stages in all clock-crossings. This allows satisfying very high MTBF requirements.
  - Modified entities: *olo_base_cc_...* and *olo_base_fifo_async*


### Non Backward Compatible Changes

All entities are backward compatible. Non backward compatible changes were applied to packages only.

- Modifications to packages to follow coding conventions. 
  - Affected entities: *olo_base_pkg_array*, , *olo_axi_pkg_protocol*, *olo_intf_i2c_master_pkg* 

- Removal of reducing logic functions from *olo_base_pkg_logic* (#85)
  - The reducing logic functions from *ieee.std_logic_misc* shall be used instead
  - Reported by: [andkae](https://github.com/andkae)

### Bugfixes (Backward Compatible)

* Fix heap-size issue for NVC simulator

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

- **CRITICAL** - Fix wrong clock crossing in *olo_base_fifo_async* (#79)
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
- *olo_base_packet_fifo*
  - Store and forward packet FIFO
  - Allows to drop packets while writing them (even after some data was written)
  - Allows skipping and repeating packets when reading them

- *olo_intf_uart*
  - UART interface

- *olo_base_decode_firstbit*
  - Timing optimal first-bit decoder

- *olo_base_cam*
  - Content addressable memory

- *olo_base_strobe_gen*
  - Added fractional mode - dynamically extend/shorten period by one clock cycle to meet the requested average strobe frequency.


### Backward Compatible Changes

- Various documentation improvements
- *olo_intf_spi_slave* 
  - Suppress needless MISO toggling at the end of a transaction (#68, reported by [betocool-prog](https://github.com/betocool-prog) )


### Non Backward Compatible Changes

- None

### Bugfixes (Backward Compatible)

- Fixed documentation of *olo_intf_spi_slave*.
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
  * Script to automatically compile all *Open Logic* features in *Questa*
  * *Questa* tutorial (VHDL and Verilog)
- Addition of *to01()* functions to *olo_base_pkg_logic*
- *olo_intf_spi_slave*
  - SPI slave
- *olo_base_cc_handshake*
  - Clock crossing with fully Read/Valid handshake but without need for distributed RAM (in contrast to *olo_base_fifo_async*)

### Backward Compatible Changes

- Various documentation improvements
  - Clarification regarding omission of ID signals in *olo_axi_master_...* (#50, contributed by [kuriousd](https://github.com/kuriousd) )
  - Remove duplicated *Ready* signal from figures in Conventions (#54, reported by [tasgomes](https://github.com/tasgomes) )
- Various optimizations on the CI/CD infrastructure
- Reduction of the latency of *olo_base_cc_pulse* by one clock cycle

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

* Efinix Efinity integration
  * Script to automatically import all *Open Logic* features into an *Efinity* project
  * Addition of synthesis attributes for *Efinity*
  * *Efinity* tutorial
* Added *FuseSoC* package manager support
* *olo_intf_spi_master*
  * SPI master

### Backward Compatible Changes

* Various documentation improvements
* Various optimizations on the CI/CD infrastructure


### Non Backward Compatible Changes

* None


### Bugfixes (Backward Compatible)

* Fixed sensitivity list in *olo_axi_master_simple* (#41)
  * *M_Axi_RResp* was missing
  * Credits to [kuriousd](https://github.com/kuriousd) for reporting
* Process scoped constraints *late* for AMD Vivado
  * User constraints must be processed before scoped constraints, otherwise clocks are not known to scoped constraints

## Credits

### Reporters

* [kuriousd](https://github.com/kuriousd) 

### Contributors

* None

## 2.0.0 

06-Jul-2024

### Added Features

* Altera Quartus integration
  * Script to automatically import all *Open Logic* features into a Quartus project
* Added tutorials
  * Vivado Verilog tutorial
  * Quartus VHDL tutorial
  * Quartus Verilog tutorial

* *olo_base_reset_gen*
  * Reset generator (and synchronizer)
* *olo_base_flowctrl_handler*
  * Allows to add flow-control (ready) around entities without flow-control (valid only)

### Backward Compatible Changes

* Various documentation improvements


### Non Backward Compatible Changes

* Removed *t_aslv* (array of unconstrained std_logic_vector) from *olo_base_pkg_array* 
  * Arrays of unconstrained types are not accepted by Quartus


### Bugfixes (Backward Compatible)

* None

## 1.2.0 

27-Jun-2024

### Added Features

* AMD Vivado integration
  * Script to automatically import all *Open Logic* features into a Vivado project
  * Vivado tutorial
* *olo_intf_clk_meas*
  * Measure the frequency of a clock signal (based on a clock with a known frequency)
* *olo_intf_debounce*
  * Debouncing for external signals (e.g. inputs from switches or buttons)

### Backward Compatible Changes

* Various documentation improvements
* Execute scoped constraint scripts in separate namespaces
  * This avoids unwanted interactions between the script through global variables


### Non Backward Compatible Changes

* None

### Bugfixes (Backward Compatible)

* Fix scoped constraints for *olo_intf_sync*
  * Incomplete input delays were reported before the fix  
* Fix inconsistencies of *olo_intf_i2c_master* generic default values compared to documentation
  * There was a mismatch for *CmdTimeout_g*
  * *ClkFrequency_g* had a default value in the implementation before the change (which is wrong because the clock is specific to the design)

## 1.1.0 

15-Jun-2024

### Added Features

* *olo_intf_i2c_master* 
  * I2C master
  * Multi-Master and clock-stretching capable
* *olo_intf_sync*
  * Double stage synchronizer for asynchronous external signals
  * Includes scoped timing constraints
* *olo_axi_master_full*
  * AXI Master with support for unaligned and odd-sized transfers (other sizes than multiple of AXI words) 

### Backward Compatible Changes

* Various documentation improvements
* Added *Rd_Last* signal to *olo_axi_master_simple* to simplify handling of read-data.
* *olo_base_wconv_n2xn* now supports InWidth=OutWidth

### Non Backward Compatible Changes

* None

### Bugfixes (Backward Compatible)

* Change default *UserTransactionSizeBits_g* in *olo_axi_master_simple* to 24 bits
  * The combination of default values before was illegal
  * Backwards compatible because the default values had to be overwritten for successful compilation before the change anyways.
* Change default values of *AlmFullLevel_g* and *AlmEmptyLevel_g* to 0
  * Using another generic (*Depth_g*) as default value for generics is illegal.
  * Backwards compatible because the default values had to be overwritten for successful compilation before the change anyways.
* Fix *AxiDataWidth_g* related assertions in *olo_axi_lite_slave*
  * Backwards compatible because the change only adds error messages for anyways illegal generics combinations    

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
