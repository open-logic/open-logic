# Compile open-logic
echo "*** Compile open-logic ***"
python3 ../../../../tools/yosys/compile_olo.py

# Compile top-level
echo "*** Compile top-level ***"
ghdl -a --std=08 -frelaxed-rules -Wno-hide -Wno-shared -Wno-unhandled-attribute cologne_tutorial.vhd

# Synthesize
echo "*** Synthesis***"
yosys -m ghdl -p '
    ghdl --std=08 -frelaxed-rules -Wno-hide -Wno-shared -Wno-unhandled-attribute cologne_tutorial;
        synth_gatemate -top cologne_tutorial -luttree -nomx8;
        write_json cologne_tutorial.json;  # write JSON netlist for implementation' > yosys.log

# Implement
echo "*** Implementation ***"
nextpnr-himbaechel \
    --device=CCGM1A1 \
    --json cologne_tutorial.json \
    -o ccf=constraints.ccf \
    -o out=impl.txt \
    --sdc timing.sdc \
    --router router2 > nexpnr.log 2>&1


# Generate bitstream
echo "*** Bitstream Generation ***"
gmpack impl.txt cologne_tutorial.bit