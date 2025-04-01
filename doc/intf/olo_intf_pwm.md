<img src="../Logo.png" alt="Logo" width="400">

# olo_intf_pwm

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_intf_pwm.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_intf_pwm.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_intf_pwm.json?cacheSeconds=0)

VHDL Source: [olo_intf_pwm](../../src/intf/vhdl/olo_intf_pwm.vhd)

## Description

TODO

## Generics

| Name         | Type      | Default | Description                    |
| :----------- | :-------- | ------- | :----------------------------- |
| MaxPeriod_g  | positive  | -       | Maximum Period in clock cycles |

## Interfaces

### Control

| Name      | In/Out | Length    | Default | Description                                     |
| :-------- | :----- | :-------- | ------- | :---------------------------------------------- |
| Clk       | in     | 1         | -       | Clock                                           |
| Rst       | in     | 1         | -       | Reset input (high-active, synchronous to _Clk_) |

### Input Interface

| Name      | In/Out | Length                    | Default       | Description                                 |
| :-------- | :----- | :------------------------ | ------------- | :------------------------------------------ |
| In_En     | in     | 1                         | -             | Enable PWM output                           |
| In_Period | in     | _log2Ceil(MaxPeriod_g+1)_ | MaxPeriod_g   | Period of output PWM signal in clock cycles |
| In_OnTime | in     | _log2Ceil(MaxPeriod_g+1)_ | -             | Number of clock cycles PWM signal is ON.    |

### Output Interface

| Name            | In/Out  | Length                    | Description                                                                                                                  |
| :-------------- | :------ | :------------------------ | :--------------------------------------------------------------------------------------------------------------------------- |
| Out_PeriodStart | out     | 1                         | Strobe signal indicating when new PWM period has started                                                                     |
| Out_PeriodCnt   | out     | _log2Ceil(MaxPeriod_g+1)_ | Counts from 0 to In_Period - 1, <br /> providing information about the current position within the period of the PWM signal. |
| Out_Pwm         | out     | 1                         | PWM signal                                                                                                                   |

## Detailed Description

TODO
