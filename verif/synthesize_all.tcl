
set script_path [file normalize [info script]]
set script_dir  [file dirname $script_path]

set results_dir_top "${script_dir}/synthesis_results"

if {[file exists $results_dir_top]} {
    file delete -force $results_dir_top
} 

file mkdir $results_dir_top

set results_summary_filename "${results_dir_top}/summary.txt"

# Create file
set summary_fileId [open $results_summary_filename w]
close $summary_fileId

set start_time [clock seconds]

foreach keystream_buffer_size { 0 } {

	set summary_fileId [open $results_summary_filename a]

	puts $summary_fileId ""
	puts $summary_fileId "*****************************************************************"
	puts $summary_fileId "*****************************************************************"
	puts $summary_fileId "              Keystream Buffer size: ${keystream_buffer_size} blocks"
	puts $summary_fileId "*****************************************************************"
	puts $summary_fileId "*****************************************************************"
	puts $summary_fileId ""

	puts $summary_fileId [format "%-15s\t%-8s\t%-8s\t%-8s\t%-8s\t%-6s\t%-6s\t%-10s\t%-10s\t%-10s\t%-15s" \
	    "Number of Cores" "LUTs" "FFs" "F7Muxes" "F8Muxes" "BRAM" "DSP" "WNS\[ns\]" "WHS\[ns\]" "WPWS\[ns\]" "Max Clock Rate \[MHz\]"]
	close $summary_fileId

	foreach cores { 1 2 3 4 5 8 15 } {
	    puts "Running with NUM_AES_CORES=$cores"

		set current_directory "${results_dir_top}/${cores}_cores___${keystream_buffer_size}_keystr_buff_size"
	    file mkdir $current_directory
	    set util_rpt_file "${current_directory}/utilization_report.rpt"
		set timing_rpt_file "${current_directory}/timing_report.rpt"


	   	#synth_design -generic NUM_AES_CORES=$cores -generic KEYSTREAM_BUFFER_SIZE=$keystream_buffer_size -generic IV_COUNTER_WIDTH=32

	   	set_property generic "NUM_AES_CORES=$cores KEYSTREAM_BUFFER_SIZE=$keystream_buffer_size IV_COUNTER_WIDTH=32" [get_filesets sources_1]
	   	launch_runs synth_1 -jobs 4
	   	wait_on_run synth_1
	   	set_property generic "" [get_filesets sources_1]

		report_utilization -name utilization_1 -file $util_rpt_file
		report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -name timing_1 -file $timing_rpt_file




		# Initialize variables to crazy valyes, to make it clear if something goes wrong.
		set LUTs -999999999
		set FFs -999999999
		set F7Muxes -999999999
		set F8Muxes -999999999
		set BRAM -999999999
		set DSP -999999999
		set WNS -999999999
		set WHS -999999999
		set WPWS -999999999

		# Open the utilization file for reading
		set fh [open $util_rpt_file r]

		# Read the file line by line
		while {[gets $fh line] >= 0} {

		    if {[string match "|*" $line]} {
		        # Split line by "|"
		        set cols [split $line "|"]
		        # Trim whitespace from each column
		        set cols [lmap c $cols {string trim $c}]
		        
		        # Check the first column for resource name
		        switch -- [lindex $cols 1] {
		            "Slice LUTs*"         { set LUTs [lindex $cols 2] }
		            "Slice Registers"     { set FFs  [lindex $cols 2] }
		            "F7 Muxes"            { set F7Muxes [lindex $cols 2] }
		            "F8 Muxes"            { set F8Muxes [lindex $cols 2] }
		            "Block RAM Tile"      { set BRAM [lindex $cols 2] }
		            "DSPs"                { set DSP [lindex $cols 2] }
		        }
		    }
		}

		# Close the file
		close $fh


		# Open the utilization file for reading
		set fh [open $timing_rpt_file r]

		# Read the file line by line
		while {[gets $fh line] >= 0} {
		    if {[string match "*Design Timing Summary*" $line]} {
		    	gets $fh line
		    	gets $fh line
		    	gets $fh line
		    	gets $fh line
		    	gets $fh line
		    	gets $fh line
		    	
				# Split line into a list with the numbers
		    	set numbers [regexp -all -inline {[-+]?\d+(?:\.\d+)?} $line]
				puts $numbers
		        
		        # Extract the key figures
				set WNS [lindex $numbers 0]
				set WHS [lindex $numbers 4]
				set WPWS [lindex $numbers 8]
		    }

		}

		# Close the file
		close $fh


		# Print results
		puts "LUTs: $LUTs"
		puts "FFs: $FFs"
		puts "F7 Muxes: $F7Muxes"
		puts "F8 Muxes: $F8Muxes"
		puts "Block RAM Tiles: $BRAM"
		puts "DSPs: $DSP"

		puts "WNS: $WNS ns"
		puts "WHS: $WHS ns"
		puts "WPWS: $WPWS ns"


		set tcl_precision 4
		set max_clk_rate_MHz [expr 1000/(4-$WNS)]

		set summary_fileId [open $results_summary_filename a]
		puts $summary_fileId [format "%-15d\t%-8d\t%-8d\t%-8d\t%-8d\t%-6d\t%-6d\t%-10.3f\t%-10.3f\t%-10.3f\t%-15.1f" \
		    $cores $LUTs $FFs $F7Muxes $F8Muxes $BRAM $DSP $WNS $WHS $WPWS $max_clk_rate_MHz]
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

puts "Total Synthesis Execution time: ${minutes}m ${seconds}s"

