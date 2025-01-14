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

# Gowin
cd $OLO_ROOT/doc/tutorials/GowinTutorial/Files
export LD_PRELOAD=/lib/x86_64-linux-gnu/libfreetype.so.6 #Workaround for Ubuntu 24.04 issue
gw_sh scripted_build_sh.tcl
gw_sh scripted_build_sv_sh.tcl

