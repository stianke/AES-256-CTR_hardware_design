
set NUM_AES_CORES [lindex $argv 0]
set KEYSTREAM_BUFFER_SIZE [lindex $argv 1]
set IV_COUNTER_WIDTH [lindex $argv 2]


set project_dir [lindex $argv 3]
set xsim_folder [lindex $argv 4]
set project_path [lindex $argv 5]


# Open your Vivado project
open_project $project_path

# Apply your Verilog defines to the simulation fileset
set_property verilog_define "NUM_AES_CORES=${NUM_AES_CORES} KEYSTREAM_BUFFER_SIZE=${KEYSTREAM_BUFFER_SIZE} IV_COUNTER_WIDTH=${IV_COUNTER_WIDTH}" [get_filesets sim_1]

# Launch simulation in scripts_only mode
launch_simulation -mode behavioral -batch -scripts_only

# Clearing the properties
set_property verilog_define {} [get_filesets sim_1]

# (Optional) close project when done
close_project


cd $xsim_folder


exec cmd.exe /c "compile.bat"
exec cmd.exe /c "elaborate.bat"
exec cmd.exe /c "simulate.bat"
