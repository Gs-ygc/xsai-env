# Vivado VIO CPU reset helper for xsai-env FPGA bring-up.
# Inspired by OpenXiangShan/env-scripts fpga_diff reset helpers.

if {$argc < 1} {
  puts "Usage: vivado -mode batch -source reset_cpu.tcl -tclargs <path/to/xsai.ltx>"
  exit 1
}

set ltx [lindex $argv 0]

proc commit_all_vio {device} {
  foreach vio [get_hw_vios -of_objects $device] {
    commit_hw_vio $vio
  }
}

proc require_probe {device pattern} {
  set probes [get_hw_probes -of_objects [get_hw_vios -of_objects $device] -filter "NAME =~ *$pattern*"]
  if {[llength $probes] == 0} {
    error "Required VIO probe not found: $pattern"
  }
  return [lindex $probes 0]
}

open_hw_manager
connect_hw_server
open_hw_target

set dev [lindex [get_hw_devices] 0]
if {$dev eq ""} {
  error "No hardware device found"
}

current_hw_device $dev
set_property PROBES.FILE $ltx $dev
refresh_hw_device $dev

set vio_sw4 [require_probe $dev "vio_sw4"]
set vio_sw5 [require_probe $dev "vio_sw5"]
set vio_sw6 [require_probe $dev "vio_sw6"]

# Halt SoC first.
set_property OUTPUT_VALUE 0 $vio_sw6
commit_all_vio $dev
after 100

# Pulse DDR reset (vio_sw4).
set_property OUTPUT_VALUE 1 $vio_sw4
commit_all_vio $dev
after 100
set_property OUTPUT_VALUE 0 $vio_sw4
commit_all_vio $dev
after 100

# Pulse CPU reset (vio_sw5).
set_property OUTPUT_VALUE 1 $vio_sw5
commit_all_vio $dev
after 100
set_property OUTPUT_VALUE 0 $vio_sw5
commit_all_vio $dev
after 100

# Release halt.
set_property OUTPUT_VALUE 1 $vio_sw6
commit_all_vio $dev

close_hw_target
disconnect_hw_server
close_hw_manager
