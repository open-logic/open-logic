<img src="./doc/Logo.png" alt="Logo" width="400">

# Changelog



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
