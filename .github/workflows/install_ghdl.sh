#!/bin/bash

# Install GHDL dependencies
sudo apt-get update
sudo apt-get install gnat libgnat-9

# Install GHDL
wget https://github.com/ghdl/ghdl/releases/download/v3.0.0/ghdl-gha-ubuntu-20.04-mcode.tgz
tar zxvf ghdl-gha-ubuntu-20.04-mcode.tgz
export PATH="$(pwd)/bin:$PATH"

# Print information
echo "GHDL version"
which ghdl
ghdl --version
