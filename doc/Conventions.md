<img src="../doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Open Logic - Coding Conventions

## Naming Conventions

### Entities

All entities are named in the form _olo\_\<area\>\_\<function\>_ where _area_ is according to the definition in this
[Readme.md](../Readme.md) and _function_ describes the functionality of the entity.

Example: An asynchronous FIFO (_fifo_async_) in the _base_ area would be named _olo_base_fifo_async_.

The naming convention is important to avoid name-clashes when compiling many _Open Logic_ files into the same VHDL
library (where also user-code may be compiled into).

### Ports

Ports are named in the form _\<interface\>_\<signal\>_.

Usually signals are grouped into interfaces. For example a block may have an AXI4-Stream input interface named _Param_
in this case the AXI4-Stream signals _TDATA_, _TVALID_ and _TREADY_ would be named _Param_TData_, _Param_TValid_ and
_Param_Tready_.

Ports do not have any _\_i_ or _\_o_ suffixes to define their direction. the direction is visible from the entity
declaration (keywords _in_ and _out_).

### Functions

Functions and procedures shall use _lowerCamelCase_.

### Constants

Constants shall have _\_c_ suffixes.

### Generics

Generics shall have _\_g_ suffixes.

### Variables

Variables shall have _\_v_ suffixes.

### Types

Types shall have _\_t_ suffixes.

For enumeration types the following additional points apply:

- FSM types shall be named _\<freely-choosable-identifier\>Fsm_t_.
- The different values for FSM types shall have _\_s_ suffixes (for "state").
- The different values of enumeration types not related to an FSM shall _NOT_ have the _\_s_ suffix (these are _NOT_
  states)

For subtypes the suffix depends on the usage:

- Subtypes that are used as types shall have _\_t_ suffixes.
- Sometimes subtypes are used as constant (e.g. to define range constants). In this case, Subtypes shall have a _\__c_
  suffix.

### Versions

[Semantic Versioning](https://semver.org/) is used for naming of releases from 1.0.0 onwards.

0.x.y relealses are considered early development and do not increase major version number in case of breaking backward
compatibility.

### Special Case: Verification Components

VUnit verification components (VCs) shall be located in the folder _\<root\>/test/tb_. They follow the VUnit naming
convention to ensure consistent testbench code when native VUnit VCs are mixed with Open Logic specific VCs.

The convention for VCs is, that all identifiers are _snail_case_ and there are no mandatory suffixes or prefixes.

The differences between VCs and Open Logic production code are only in the case of identifiers. To keep the linter
happy, instantiation of VCs (which are VUnit case-style) in test-benches (which are Open Logic case-style) are written
in _Open Logic_ case-style. This is possible due to the case insensitivity of VHDL.

```vhdl
-- VC Code (VUnit case-style)
entity some_vc is
    generic (
        some_generic : string
    )
    port (
        some_port : string
    );
end entity;

-- Instantiation in test-bench (Open-Logic case-stlye)
vc_any : entity work.some_vc
    generic map (
        Some_Generic => "bla"
    )
    port map (
        Some_Port => TbSignal
    );
```

### Other Naming Conventions

There are a few other naming conventions (e.g. for process and generic labels). Indentation is best understood by
looking at existing code.

Instead of documenting them in detail, the linter was configured to enforce them (see [How To](./HowTo.md)). It is
suggested that you write the code according to the coding conventions as good as you can and then you clean-up all
linter errors and warnings.

**Note:** All linting errors _and warnings_ must be resolved for pull-requests to be accepted.

## Coding Convention

### White Spaces

- Indentation is done using four whitespaces per level.
- No tabs shall be used.
- Files shall not contain trailing whitespaces.

### Indentation

Indentation is best understood by looking at existing code. From there on, the linter will guide you (see
[How To](./HowTo.md)). It is suggested that you write the code according to the coding conventions as good as you can
and then you clean-up all linter errors and warnings.

**Note:** All linting errors _and warnings_ must be resolved for pull-requests to be accepted.

## Functional Conventions

### AXI4-Stream Handshaking Signals

Handshaking signals follow the de-facto industry standard AXI4-Stream. You will find the signals _Valid_ (TVALID) and
_Ready_ (TREADY) wherever handshaking is required. However, data-signals (TDATA) might be named differently depending on
the functionality of a given component.

### Reset

All resets are synchronous and high-active.

Synchronous resets were chosen because depending on the use-case, the reset signal may be controlled from ordinary logic
(which may contain glitches). For example the reset signal of a FIFO may be used during normal operation to flush the
FIFO.

If you need active low resets, you you must invert the reset (to create a high-active reset) external to _Open Logic_
entities.

Only the registers containing state shall be reset. Pipeline registers shall not be reset to keep reset fanout low.

Reset shall be implemented as override at the end of the process, not using an _if_ at the beginning of the process.
See example below:

How reset **SHALL** be implemented:

```vhdl
good : process(Clk)
begin
    if rising_edge(Clk) then
        A <= x;
        B <= y;
        if Rst = '1' then
            A <= '0';
        end if;
    end if;
end;
```

In this implementation, _A_ results in a D-FF with reset, B results in a D-FF without reset. Hence reset fanout is low.

How reset shall **NOT** be implemented:

```vhdl
bad : procesS(Clk)
begin
    if rising_edge(Clk) then
        if Rst = '1' then
            A <= '0';
        else
            A <= x;
            B <= y;
        end if;
    end if;
end if;
```

In this implementation, _A_ results in a D-FF with reset and _B_ results in a D-FF with _Rst_ as clock enable. Hence
reset fanout is needlessly high.

### Default Values

All optional generics and ports have default values. If a user does not need optional ports or generics, he does not
have to care about them and find out what would be an appropriate default value.

### TDM (Time Division Multiplexing)

Rules:

- If multiple signals are transferred TDM (time-division-multiplexed) over the same interface and all signals have the
  same sample rate, no additional channel indicator is implemented and looping through the channels is implicit (e.g.
  for a three channel link, samples are transferred in the channel order 0-1-2-0-1-2-…).<br>

![TDM](./general/tdm.png)<br>

The entities blocks can be used to convert between parallel channel handling and TDM:

- [olo_base_wconv_xn2n](./base/olo_base_wconv_xn2n.md) - Parallel to TDM
- [olo_base_wconv_n2xn](./base/olo_base_wconv_n2xn.md) - TMD to Parallel

TDM signals can be difficult to debug because the channel mapping is hard to identify at runtime. It usually is a good
idea to mark the last channel for each sample by _Last_ as shown in the figure below. This way, it is easily known which
data-beat belongs to which channel.

![TDM-Last](./general/tdm_last.png)

For packetized data, the last channel of the last sample of a packet is marked by _Last_. As a result, the channel
mapping can be reconstructed easily at packet boundaries.

![TDM-Packet](./general/tdm_packet.png)

## Testbenching

### VUnit

The [VUnit](https://vunit.github.io/) verification framework is used to verify _Open Logic_. All testbenches shall be
VUnit testbenches and different test-cases shall be properly separated.

VUnit was chosen because it allows to easily use both, commercial tools like _Questasim_ and the open source simulators
_GHDL_ and _NVC_. Additionally VUnit allows to write well structures test-benches and simplifies regression testing a
lot.

### Coverage

A code coverage of 100% is the goal. For code with generics, a representable set of combinations of generics shall be
simulated.

## Documentation

Documentation is written in Markdown. Conventions are checked using markdownlint, it's best to install the VSCode
plugin, so linting errors can be seen while editing files.

The following conventions are important to rembmer:

- For unordered lists, dashes (`-`) are used
- For _emphasizing_ underscores (`_`) are used

The markdown linting is executed automatically and pull-requests are only accepted if there are no errors reported.
