link
source ./timing.sdc
# Separate timing path groups.
set ports_clock_root [filter_collection [get_attribute [get_clocks] sources] object_class==port]
group_path -name REGOUT -to [all_outputs]
group_path -name REGIN -from [remove_from_collection [all_inputs] ${ports_clock_root}]
group_path -name FEEDTHROUGH -from [remove_from_collection [all_inputs] ${ports_clock_root}] -to [all_outputs]
# I am not sure what's these lines, but it is a common settings.
set_fix_multiple_port_nets -all -buffer_constant
check_design
