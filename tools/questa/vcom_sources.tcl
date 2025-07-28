###############################################################################
# Copyright (c) 2024 by Oliver Bruendler, Switzerland
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
    vcom -autoorder -work olo $oloRoot/src/*/vhdl/*.vhd
}
