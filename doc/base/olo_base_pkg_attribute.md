<img src="../Logo.png" alt="Logo" width="400">

# olo_base_pkg_attribute

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](<https://img.shields.io/badge/statement coverage-No Code-green?cacheSeconds=0>)
![Endpoint Badge](<https://img.shields.io/badge/statement coverage-No Code-green?cacheSeconds=0>)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_pkg_math.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_attribute](../../src/base/vhdl/olo_base_pkg_attribute.vhd)

## Description

This package contains synthesis attributes for various vendors.

The usage is non-straightforward because different attributes must be added due to restrictions of VHDL. Also does the
package only contain attributes used in Open Logic internally. As a result, **this package is meant for internal use**
mainly and it is **undocumented**.

Users are still free to use the package but no support will be given. If you decide to do so, orient yourself on code
samples (e.g. in [olo_base_cc_bits](./olo_base_cc_bits.md) or [olo_base_ram_sdp](./olo_base_ram_sdp.md)) and on the
comments within the source code of the package.

Currently only one version of the package is provided. In case of unresolvable name clashes between attributes expected
by different tools, the package might be provided in different versions for different tools in future.
