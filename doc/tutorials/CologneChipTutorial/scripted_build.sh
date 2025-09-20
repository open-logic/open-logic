# Compile open-logic
python3 ../../../tools/yosys/compile_olo.py

# Compile top-level
ghdl -a --std=08 -frelaxed-rules -Wno-hide -Wno-shared cologne_tutorial.vhd

# Synthesize
yosys -m ghdl -p '
    ghdl --std=08 -frelaxed-rules -Wno-hide -Wno-shared cologne_tutorial;
        synth_gatemate
            -top cologne_tutorial   # top module name
            -luttree                # mandatory: enable luttree support
            -nomx8                  # mandatory: disable MUX8 support
        write_json cologne_tutorial.json;  # write JSON netlist for implementation'
