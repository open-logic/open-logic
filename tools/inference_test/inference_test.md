# Inference Test

## Introduction

The goal of the inference testing tool is to run synthesis for multiple entities, with multiple generics configurations
and using the different supported tools. First to check if synthesis is successful and second to compare resource usage
for different generics combinations and detect unexpected numbers.

Why is this required? Synthesis might fail for various reasons. Some tools may fail on certain statements, even if they
are completely valid VHDL. This situation has to be detected and avoided in order to make _Open Logic_ as portable as
it shall be.

## Setup

The inference testing environment is generally implemented as python3 application. It does make use of _jinja2_
templating to generate top-level VHDL files to synthesize and synthesis scripts for various tools. The information
about which entities have to be synthesized with which generics combination is stored in a YAML file.

**Note:** The whole setup is aimed at its use in _Open Logic_. It may contain simplifications that do work with the
_Open Logic_ coding guidelines but not with other VHDL code. The same applies to the YAML file parsing - the setup is
not optimized for the very best error reporting messages in cases of errors in the YAML.

## YAML

The YAML file is structured into the following main sections:

### File Selection

Example:

```YML
files:
  include:
    - "src/**/*.vhd"  # Glob expressions for files to parse
    - "lib/**/*.vhd"
  exclude:
    - "test_*"        # Exclude entities matching this glob pattern
    - "debug_*"
```

This section defines what files to parse for entities. 

### Excluded Entities

Example:

```yaml
exclude_entities:
  - "olo_fix_sim_*" # Simulation only
  - "olo_fix_to_real" # Simulation only
  - "olo_fix_private_*" # Private entities
```

The framework does check if all entities in the files defined are tested. If this is not the case, and the
`--check_coverage` option is used, errors are reported. This is useful to ensure all entities are synthesized in CI
runs.

If an entity shall not be tested for good reasons, a pattern to match it can be provided here. In this case no errors
are reported.

### Configuration Definition

Example:

```YML
entities:
  - entity_name: "MyEntity1"
    fixed_generics:
      Depth_g: 256
      Width_g: 32
    configurations:
      - name: "Config1"
        generics:
          Mode: "default"
          Enable: true
        omitted_ports:
          - Match_Match
          - Match_Valid        
      - name: "Config2"
        generics:
          Mode: "optimized"
          Enable: false
        in_reduce:
          In_A: 32
          In_B: 32
        out_reduce:
          Result: 48
    tool_generics:
      vivado:
        - ClockSpeed: 100
  - entity_name: "MyEntity2"
    ..On the first level, every entity to be synthesized is given.
```

The `fixed_generics` option does allow to set some generics to the same value for all configuration. This can be useful
to avoid needless repetition in the YAML file.

Then the `configurations`are given. Every configuration can _optionally_ have the following entries:

- Generics to set (`generics`)
- Ports to omit (`omitted_ports`)
  - This can be useful to see resource usage  with some ports not connected.
  - This also can be useful to limit the I/O count*
- Reduction of input (`in_reduce`) and output (`out_reduce`) ports
  - This leads to the listed ports being connected to shift registers. 
  - These ports are not optimized away and hence resources are reported correctly
  - This also can be useful to limit the I/O count*
  - The approximate amount of resource introduced by the shift registers is subtracted from the reported resources
  - automatically

\* Reduction of I/O count is required because some tools do fail synthesis if the top-level design has more I/Os than
the target device.

The `tool_generics` section allows to chose tool-dependent values for certain generics. This might be useful e.g. if
some tools do not support certain functionality.

The tools supported currently are:

- vivado
- quartus
- efinity
- gowin
- libero

## Top Level Handling

Because not all tools supported by _Open Logic_ do allow setting the generics of the top-level entity, it is not
possible to use individual _Open Logic_ components as top level entities directly. Many of them have generics without
default values and therefore would fail.

Therefore, the inference testing framework automatically creates a top-level wrapper (_inference_test/test.vhd_) around
the tested entity. In this wrapper all generics are assigned.

Additionally this wrapper also does the I/O reduction mentioned further up.

The top-level file is generated using _jinja2_ from the template _inference_test/top.template_.

## Tool Execution

To run synthesis, the tools are operated in batch mode. The scripts (usually TCL) to execute for a synthesis run are
generated using _jinja2_ from the templates in _inference_test/\<tool\>/\<name\>.template_.

Those templates do use the _Open Logic_ tool integration scripts provided natively by _Open Logic_.

After synthesis is executed, the report files are parsed to extract resource information.

## Debugging

The whole inference test framework is written with the goal to synthesize all _Open Logic_ entities in CI.
**The inference test framework is not meant as a product** and not delivered in production quality. Error reports may
be hard to interpret for untrained users.

There are two main categories of errors:

- Errors during synthesis
  - For those errors, it is most helpful to look into the log files from the tools itself in _inference_test/project_.
    The project is left on the disk for analysis in this case.
- Other errors
  - Those might be located in the python code or in the YML file. It's not always easy to differentiate.
  - As a rule of thumb - try to find errors in added YML code by removing line by line and see when the error
    disappears.

Sometimes it also is helpful to read the generated _inference_test/test.vhd_ file in order to see if it looks as
expected in the failing case.