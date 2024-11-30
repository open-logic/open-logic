#!/bin/bash

# Exit on the first error
set -ex

# Set root directory
OLO_ROOT=$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")
echo "Open-Logic Root: $OLO_ROOT"

# Vivado
cd $OLO_ROOT/doc/tutorials/VivadoTutorial/Files
vivado -mode batch -source scripted_build.tcl
vivado -mode batch -source scripted_build_sv.tcl

# Quartus
cd $OLO_ROOT/doc/tutorials/QuartusTutorial/Files
quartus_sh -t scripted_build.tcl
quartus_sh -t scripted_build_sv.tcl

# Efinity
cd $OLO_ROOT/doc/tutorials/EfinityTutorial/Files/prj_vhdl
efx_run --prj ./prj_vhdl.xml
cd $OLO_ROOT/doc/tutorials/EfinityTutorial/Files/prj_verilog
efx_run --prj ./prj_verilog.xml

# Questa
cd $OLO_ROOT/doc/tutorials/QuestasimTutorial/Files
vsim <<< "source ./scripted_run.tcl; quit -f"
vsim <<< "source ./scripted_run_sv.tcl; quit -f"

# Libero
cd $OLO_ROOT/doc/tutorials/LiberoTutorial/Files
libero script:scripted_build.tcl
libero script:scripted_build_sv.tcl

