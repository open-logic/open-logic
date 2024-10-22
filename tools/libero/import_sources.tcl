#Automatically import all open-logic sources into a Libero project

namespace eval olo_import_sources {

	##################################################################
	# Helper Functions
	##################################################################
	# Create relative path (TCL interpreter does not yet know "file relative")
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

    #Find folder of this file and olo-root folder
    variable fileLoc [file normalize [file dirname [info script]]]
    variable oloRoot [file normalize $fileLoc/../..]

	#Create library
	add_library -library {olo} 

    #Add all source files
    foreach area {base axi intf} {
        variable files [glob $oloRoot/src/$area/vhdl/*.vhd]
	    foreach f $files {
			variable pathRelative [relpath $f [pwd]]
			create_links -convert_EDN_to_HDL 0 -library {olo} -hdl_source $pathRelative 
	    }
    }
}
