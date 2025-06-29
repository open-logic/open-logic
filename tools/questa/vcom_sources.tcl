###############################################################################
# Copyright (c) 2024 by Oliver Bründler, Switzerland
# All rights reserved.
# Authors: Oliver Bruendler
###############################################################################

namespace eval olo_import_sources {
    
    ##################################################################
    # Script
    ##################################################################
    
    #Get olo location
    variable fileLoc [file normalize [file dirname [info script]]]
    variable oloRoot [file normalize $fileLoc/../..]
    
    #Compile
    vcom -2008 -autoorder -work olo $oloRoot/3rdParty/en_cl_fix/hdl/*.vhd
    vcom -2008 -autoorder -work olo $oloRoot/src/*/vhdl/*.vhd
}
