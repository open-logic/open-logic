#Automatically import all open-logic sources into a Quartus project

namespace eval olo_import_sources {

	package require ::quartus::project

	##################################################################
	# Helper Functions
	##################################################################
	# Create relative path (vivados interpreter does not yet know "file relative")
	proc relpath {targetPath basePath} {
		# Normalize paths to remove any "..", "." or symbolic links
		set targetPath [file normalize $targetPath]
		set basePath [file normalize $basePath]

		# Split paths into lists
		set targetList [file split $targetPath]
		set baseList [file split $basePath]

		# Remove common prefix
		while {[llength $baseList] > 0 && [llength $targetList] > 0 && [lindex $baseList 0] eq [lindex $targetList 0]} {
		    set baseList [lrange $baseList 1 end]
		    set targetList [lrange $targetList 1 end]
		}

		# For each remaining directory in baseList, prepend "../" to targetList
		set relativeList {}
		for {set i 0} {$i < [llength $baseList]} {incr i} {
		    lappend relativeList ..
		}
		set relativeList [concat $relativeList $targetList]

		# Join the list back into a path
		return [join $relativeList "/"]
	}

    ##################################################################
    # Script
    ##################################################################

	#Open Logic requires VHDL 2008
	set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008

    #Find folder of this file and olo-root folder
	variable projectLoc [get_project_directory]
    variable fileLoc [file normalize [file dirname [info script]]]
    variable oloRoot [file normalize $fileLoc/../..]

    #Add all source files
    foreach area {base axi intf fix} {
        variable files [glob $oloRoot/src/$area/vhdl/*.vhd]
	    foreach f $files {
			variable pathRelative [relpath $f $projectLoc]
	        set_global_assignment -name VHDL_FILE $pathRelative -library olo
	    }
    }

	#Add 3rd party files
	variable files [glob $oloRoot/3rdParty/en_cl_fix/hdl/*.vhd]
	foreach f $files {
		variable pathRelative [relpath $f $projectLoc]
		set_global_assignment -name VHDL_FILE $pathRelative -library olo
	}

}
