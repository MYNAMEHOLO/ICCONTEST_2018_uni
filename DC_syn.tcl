#Read All Files
read_verilog ../rtl/LCD_CTRL.v
current_design LCD_CTRL
link

#Setting Clock Constraints
source -echo -verbose LCD_CTRL.sdc

#Synthesis all design
compile -map_effort high -area_effort high
compile -map_effort high -area_effort high -inc

change_names -hierarchy -rule verilog

define_name_rules name_rule \
      -allowed {a-z A-Z 0-9 _} \
      -max_length 255 -type cell

define_name_rules name_rule \
      -allowed {a-z A-Z 0-9 _[]} \
      -max_length 255 -type net

define_name_rules name_rule \
      -map {{"\\*cell\\*" "cell"}}

define_name_rules name_rule \
      -case_insensitive

change_names -hierarchy -rules name_rule

remove_unconnected_ports \
    -blast_buses [get_cells -hierarchical *]

write -format ddc     -hierarchy -output "LCD_CTRL_syn.ddc"
write_sdf LCD_CTRL_syn.sdf
write_file -format verilog -hierarchy -output LCD_CTRL_syn.v
report_area > area.log
report_timing > timing.log
report_qor   >  LCD_CTRL_syn.qor

