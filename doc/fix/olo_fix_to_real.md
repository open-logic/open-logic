<img src="../Logo.png" alt="Logo" width="400">

# olo_fix_to_real

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_fix_to_real.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_fix_to_real.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_fix_to_real.json?cacheSeconds=0)

VHDL Source: [olo_fix_to_real](../../src/fix/vhdl/olo_fix_to_real.vhd)
Bit-true Model: [olo_fix_to_real](../../src/fix/python/olo_fix/olo_fix_to_real.py)

## Description

This entity converts a a fixed-point number to real (floating-point).

Real numbers are not used for synthesis normally. The _olo_fix_to_real_ entity has the following main use-case:

- Create real representation of fixed-point values in simulation
  - Example: Motor controller simulation
  - The output of the motor controller entity is fixed point.
  - The physical motor model expects inputs in real format (easiest for modelling)
  - _olo_fix_to_real_ is used to do the conversion

Note that this entity does not contain any pipeline registers. Real (floating-point) values do no exist in synthesized
netlists - so the conversion mainly is executed in simulations. Hence no registers are needed.

For details about the fixed-point number format used in _Open Logic_, refer to the
[fixed point principles](./olo_fix_principles.md).

## Generics

| Name        | Type    | Default   | Description                                                  |
| :---------- | :------ | --------- | :----------------------------------------------------------- |
| AFmt_g      | string  | -         | Format of the input<br />String representation of an _en_cl_fix Format_t_ (e.g. "(0,1,15)") |

## Interfaces

### Input Data

| Name     | In/Out | Length          | Default | Description                               |
| :------- | :----- | :-------------- | ------- | :---------------------------------------- |
| In_A     | in     | _width(AFmt_g)_ | -       | Input data                                |

### Output Data

| Name       | In/Out | Length               | Default | Description                               |
| :--------- | :----- | :------------------- | ------- | :---------------------------------------- |
| Out_Value  | out    | N/A (real)           | N/A     | Output data  |

## Detail

No detailed description required. All details that could be mentioned here are already covered by
[fixed point principles](./olo_fix_principles.md).
