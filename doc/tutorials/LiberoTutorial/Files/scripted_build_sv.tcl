# Create Project
new_project -location {./tutorial_prj_sv} -name {tutorial_prj_sv} -project_description {} -block_mode 0 -standalone_peripheral_initialization 0 -instantiate_in_smartdesign 1 -ondemand_build_dh 1 -use_relative_path 0 -linked_files_root_dir_env {} -hdl {Verilog} -family {PolarFireSoC} -die {MPFS250T} -package {FCVG484} -speed {STD} -die_voltage {1.0} -part_range {EXT} -adv_options {IO_DEFT_STD:LVCMOS 1.8V} -adv_options {RESTRICTPROBEPINS:0} -adv_options {RESTRICTSPIPINS:0} -adv_options {SYSTEM_CONTROLLER_SUSPEND_MODE:0} -adv_options {TEMPR:EXT} -adv_options {VCCI_1.2_VOLTR:EXT} -adv_options {VCCI_1.5_VOLTR:EXT} -adv_options {VCCI_1.8_VOLTR:EXT} -adv_options {VCCI_2.5_VOLTR:EXT} -adv_options {VCCI_3.3_VOLTR:EXT} -adv_options {VOLTR:EXT} 
set_device -family {PolarFireSoC} -die {MPFS250T_ES} -package {FCVG484} -speed {STD} -die_voltage {1.0} -part_range {EXT} -adv_options {IO_DEFT_STD:LVCMOS 1.8V} -adv_options {RESTRICTPROBEPINS:0} -adv_options {RESTRICTSPIPINS:0} -adv_options {SYSTEM_CONTROLLER_SUSPEND_MODE:0} -adv_options {TEMPR:EXT} -adv_options {VCCI_1.2_VOLTR:EXT} -adv_options {VCCI_1.5_VOLTR:EXT} -adv_options {VCCI_1.8_VOLTR:EXT} -adv_options {VCCI_2.5_VOLTR:EXT} -adv_options {VCCI_3.3_VOLTR:EXT} -adv_options {VOLTR:EXT} 

# Import tutorial file
create_links \
         -convert_EDN_to_HDL 0 \
         -library {work} \
         -hdl_source {./libero_tutorial.sv} 

# Import open logic 
# Import into library "work" because this is required by SynplifyPro when instantiating VHDL from Verilog
set argv [list "lib=work"]
source ../../../../tools/libero/import_sources.tcl

# Set top module
build_design_hierarchy 
set_root -module {libero_tutorial::work}

# Import constraints
create_links \
         -convert_EDN_to_HDL 0 \
         -sdc {./constraints.sdc} 
create_links \
         -convert_EDN_to_HDL 0 \
         -io_pdc {./pinout.pdc} 
run_tool -name {CONSTRAINT_MANAGEMENT} 
organize_tool_files -tool {PLACEROUTE} -file {./pinout.pdc} -module {libero_tutorial::work} -input_type {constraint} 
set_device_simple -family {PolarFireSoC} -die {MPFS250T_ES} -package {FCVG484} -speed {STD} -die_voltage {1.0} -part_range {EXT} -adv_options {IO_DEFT_STD:LVCMOS 1.8V} -adv_options {RESERVEMIGRATIONPINS:1} -adv_options {RESTRICTPROBEPINS:0} -adv_options {RESTRICTSPIPINS:0} -adv_options {SYSTEM_CONTROLLER_SUSPEND_MODE:0} -adv_options {TEMPR:EXT} -adv_options {VCCI_1.2_VOLTR:EXT} -adv_options {VCCI_1.5_VOLTR:EXT} -adv_options {VCCI_1.8_VOLTR:EXT} -adv_options {VCCI_2.5_VOLTR:EXT} -adv_options {VCCI_3.3_VOLTR:EXT} -adv_options {VOLTR:EXT} 
organize_tool_files -tool {SYNTHESIZE} -file {./constraints.sdc} -module {libero_tutorial::work} -input_type {constraint} 
organize_tool_files -tool {PLACEROUTE} -file {./pinout.pdc} -file {./constraints.sdc} -module {libero_tutorial::work} -input_type {constraint} 
organize_tool_files -tool {VERIFYTIMING} -file {./constraints.sdc} -module {libero_tutorial::work} -input_type {constraint} 

# Build Project
run_tool -name {PLACEROUTE} 
run_tool -name {VERIFYTIMING} 

# Export Bitstream and FlashPro Job 
export_bitstream_file \
         -file_name {libero_tutorial} \
         -export_dir {./tutorial_prj_sv/designer/libero_tutorial/export} \
         -format {DAT PPD} \
         -for_ihp 0 \
         -limit_SVF_file_size 0 \
         -limit_SVF_file_by_max_filesize_or_vectors {} \
         -svf_max_filesize {} \
         -svf_max_vectors {} \
         -master_file 0 \
         -master_file_components {} \
         -encrypted_uek1_file 0 \
         -encrypted_uek1_file_components {} \
         -encrypted_uek2_file 0 \
         -encrypted_uek2_file_components {} \
         -trusted_facility_file 1 \
         -trusted_facility_file_components {FABRIC SNVM} \
         -zeroization_likenew_action 0 \
         -zeroization_unrecoverable_action 0 \
         -master_backlevel_bypass 0 \
         -uek1_backlevel_bypass 0 \
         -uek2_backlevel_bypass 0 \
         -master_include_plaintext_passkey 0 \
         -uek1_include_plaintext_passkey 0 \
         -uek2_include_plaintext_passkey 0 \
         -sanitize_snvm 0 \
         -sanitize_envm 0 \
         -trusted_facility_keep_fabric_operational 0 \
         -trusted_facility_skip_startup_seq 0 \
         -trusted_facility_mss_keep_alive 0 \
         -uek1_keep_fabric_operational 0 \
         -uek1_skip_startup_seq 0 \
         -uek1_mss_keep_alive 0 \
         -uek1_high_water_mark {} \
         -uek2_keep_fabric_operational 0 \
         -uek2_skip_startup_seq 0 \
         -uek2_mss_keep_alive 0 \
         -uek2_high_water_mark {} 
configure_snvm -cfg_file {./tutorial_prj_sv/designer/libero_tutorial/SNVM.cfg} 
export_prog_job \
         -job_file_name {libero_tutorial} \
         -export_dir {./tutorial_prj_sv/designer/libero_tutorial/export} \
         -bitstream_file_type {TRUSTED_FACILITY} \
         -bitstream_file_components {FABRIC SNVM} \
         -zeroization_likenew_action 0 \
         -zeroization_unrecoverable_action 0 \
         -program_design 1 \
         -program_spi_flash 0 \
         -include_plaintext_passkey 0 \
         -design_bitstream_format {PPD} \
         -prog_optional_procedures {} \
         -skip_recommended_procedures {} \
         -sanitize_snvm 0 \
         -sanitize_envm 0 



