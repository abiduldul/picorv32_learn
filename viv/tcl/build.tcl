source viv/tcl/set_variables.tcl

set path_report $dir_origin/$dir_report
set path_bitstream $dir_origin/$dir_bitstream

# read rtl
set_part $fpga_part
proc get_verilog_files {dir} {
    set files {}
    foreach f [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $f]} {
            set files [concat $files [get_verilog_files $f]]
        } elseif {[string match *.v $f]} {
            lappend files $f
        }
    }
    return $files
}
set all_verilog_files [get_verilog_files [file join $dir_origin $dir_rtl]]
read_verilog $all_verilog_files

# run synthesis
read_xdc "$dir_origin/$dir_xdc/$filename_xdc"
synth_design -top $top_level
write_checkpoint -force $dir_out/post_synth.dcp
report_timing_summary -file $path_report/timing_syn.rpt

# run implementation
opt_design
place_design
write_checkpoint -force $dir_out/post_place.dcp
report_timing -file $path_report/timing_place.rpt
phys_opt_design
route_design
write_checkpoint -force $dir_out/post_route.dcp
report_timing_summary -file $path_report/timing_summary
write_bitstream -force $path_bitstream/$filename_bitstream