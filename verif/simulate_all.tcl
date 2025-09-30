
set script_path [file normalize [info script]]
set script_dir  [file dirname $script_path]

set results_dir_top "${script_dir}/simulation_results"

if {[file exists $results_dir_top]} {
    file delete -force $results_dir_top
} 

file mkdir $results_dir_top

set results_summary_filename "${results_dir_top}/summary.txt"

# Create file
set summary_fileId [open $results_summary_filename w]
close $summary_fileId

set start_time [clock seconds]

# If a previous simulation is running, close it.
catch {close_sim -force}


set default_sim_log "[get_property DIRECTORY [current_project]]/[get_property NAME [current_project]].sim/sim_1/behav/xsim/simulate.log"

foreach keystream_buffer_size { 0 } {

    set summary_fileId [open $results_summary_filename a]

    puts $summary_fileId ""
    puts $summary_fileId "*****************************************************************"
    puts $summary_fileId "*****************************************************************"
    puts $summary_fileId "              Keystream Buffer size: ${keystream_buffer_size} blocks"
    puts $summary_fileId "*****************************************************************"
    puts $summary_fileId "*****************************************************************"
    puts $summary_fileId ""

    close $summary_fileId

    foreach cores { 1 2 3 4 5 8 15 } {
        puts "Running with NUM_AES_CORES=$cores"

        set summary_fileId [open $results_summary_filename a]
        puts $summary_fileId "Running with NUM_AES_CORES=$cores. Printout from synthesis log:"
        close $summary_fileId


        set current_directory "${results_dir_top}/${cores}_cores___${keystream_buffer_size}_keystr_buff_size"
        set sim_log "${current_directory}/simulate.log"

        puts "Deleting old simulation file"
        catch {file delete -force $default_sim_log}

        puts "Setting generic properties"
        set_property verilog_define "NUM_AES_CORES=$cores KEYSTREAM_BUFFER_SIZE=$keystream_buffer_size IV_COUNTER_WIDTH=32" [get_filesets sim_1]

        puts "Launching simulation"
        launch_simulation -mode behavioral
        
        puts "Wait 5 sec"
        #wait_on_runs [current_sim]
        after 5000
        
        puts "Waiting until completion"
        run all
        
        puts "Closing simulation"
        close_sim -force
        
        puts "Clearing generic properties"
        set_property verilog_define {} [get_filesets sim_1]

        puts "Moving simulation results to seperate directory"
        
        #file rename -force $default_sim_log $sim_log
        file mkdir $current_directory
        file copy -force $default_sim_log $sim_log

        
        puts "Parsing the simulation results..."


        # Open the simulation log for reading
        set fh [open $sim_log r]

        while {[gets $fh line] >= 0} {
            if {[string match "*Simulation started with generics*" $line] || \
                [string match "*Failed*" $line]|| \
                [string match "*Simulation finished successfully*" $line]} {
                
                # Write the result (success/failure) to the summary file.
                set summary_fileId [open $results_summary_filename a]
                puts $summary_fileId "\t$line"
                close $summary_fileId
            }

        }

        # Close the file
        close $fh


        # Write some newlines to the summary log
        set summary_fileId [open $results_summary_filename a]
        puts $summary_fileId ""
        puts $summary_fileId ""
        close $summary_fileId

    }

    set summary_fileId [open $results_summary_filename a]
    puts $summary_fileId ""
    puts $summary_fileId ""
    puts $summary_fileId ""
    close $summary_fileId
}


set end_time [clock seconds]
set elapsed [expr {$end_time - $start_time}]

set minutes [expr {$elapsed / 60}]
set seconds [expr {$elapsed % 60}]

puts "Total Simulation Execution time: ${minutes}m ${seconds}s"



