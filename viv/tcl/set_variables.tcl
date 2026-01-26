# set board_name "basys3"
# set fpga_part "xc7a35tcpg236-1"

set board_name "zynq7000"
set fpga_part "xc7z020clg400-1"

# set project
set project_name "picorv32"
set top_level "picorv32_soc"
set top_level_tb "tb_${top_level}.v"

# set template directory
set dir_rtl "rtl"
set dir_tb "tb"
set dir_xdc "viv/xdc"
set dir_out "viv/out"
set dir_log "viv/out/log"
set dir_report "viv/res/report"
set dir_bitstream "viv/res"

# set reference directories for source files
set dir_origin [file normalize "."]
puts "INFO: dir_origin is  $dir_origin"


# set file constrains
set filename_xdc "${board_name}_${project_name}.xdc"
set filename_bitstream "${board_name}_${project_name}.bit"