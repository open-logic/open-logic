#!/bin/bash

# Pass version (e.g. 3.0.1) as argument

# Exit on the first error
set -ex

# Set root directory
OLO_ROOT=$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")
echo "Open-Logic Root: $OLO_ROOT"

# Info
echo "Build Version $1"

# Set-up fusesoc
mkdir fusesoc
cd fusesoc
fusesoc library add open-logic https://github.com/open-logic/open-logic

# Build Vivado
fusesoc run --tool vivado --target zybo_z7 open-logic:tutorials:vivado_tutorial:$1

# Build Quartus
fusesoc run --tool quartus --target de0_cv open-logic:tutorials:quartus_tutorial:$

