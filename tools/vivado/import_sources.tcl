#Automatically import all open-logic sources into a Vivado project
namespace eval olo_import_sources {

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

	#Find folder of this file and olo-root folder
	variable fileLoc [file normalize [file dirname [info script]]]
	variable oloRoot [file normalize $fileLoc/../..]

	#Add all source files
	foreach area {base axi intf} {
		add_files $oloRoot/src/$area/vhdl
		set_property LIBRARY olo [get_files -all *olo_$area\_*]
	}

	#For constraints, a new TCL file is created which points to 
	#... the imported TCL files relatively from the impl_1 directory
	#... inside the vivado project (because vivado copies TCL files
	#... there for execution).
	variable projectDir [get_property DIRECTORY [current_project]]
	variable runDir [file normalize $projectDir/prj.runs/impl_x]
	variable constraintsTcl [relpath $oloRoot/tools/vivado/all_constraints_amd.tcl $runDir] 
	variable oloDir $projectDir/open_logic
	
	#Create open-logic directory if it does not exist
	if {![file exists $oloDir]} {
		file mkdir $oloDir
	}
	
	#Create constraints file
	variable fileId [open $oloDir/olo_scoped_constraints.tcl "w+"]
	#puts $fileId $runDir
	#puts $fileId $oloRoot/tools/vivado/all_constraints_amd.tcl
	puts $fileId "source $constraintsTcl"
	close $fileId
	
	#Add cosntraints file to project
	add_files -fileset constrs_1 -norecurse $oloDir/olo_scoped_constraints.tcl
	set_property used_in_synthesis false [get_files $oloDir/olo_scoped_constraints.tcl]
	set_property used_in_simulation false [get_files $oloDir/olo_scoped_constraints.tcl]
	set_property PROCESSING_ORDER LATE [get_files $oloDir/olo_scoped_constraints.tcl]
}


