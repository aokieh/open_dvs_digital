
set toolPath [split [info nameofexecutable] /]
set toolName [lindex $toolPath end]

set_time_unit -nanoseconds
set_load_unit -femtofarads

#------------------------------
# SDC Constants
#------------------------------
# Constants used in constraints 

# set CLK_P <value>;

#------------------------------
# Mode  Definitions 
#------------------------------

#set_case_analysis <string> <port|pin|hpin>+

#set_logic_one  <ports_pins>

#set_logic_zero <ports_pins>

#------------------------------
# Clock Definitions 
#------------------------------

#create_clock [-add] [-name <CKP_string>] [-comment <string>] [-domain <string>] -period <float> [-waveform <float>+] \
#             [-apply_inverted <port|pin|hpin>+] [<port|pin|hpin>+]


#create_generated_clock [-name <CKG_string>] [-comment <string>] [-domain <string>] [-add] -source <pin|hpin|port>       \
#           [-master_clock <clock>] [-divide_by <integer>] [-multiply_by <integer>] [-duty_cycle <float>] [-invert]  \
#           [-edges <integer>+] [-edge_shift <float>+] [-apply_inverted <object>+] [-combinational] <pin|hpin|port>+


#------------------------------
# Clock Groups
#------------------------------
# Use named lists of clock names to group synchronous clocks; 


# set_clock_groups [-name <GRP_string>] [-comment <string>] [-logically_exclusive | -physically_exclusive | -asynchronous] [-allow_paths] \
#                  (-group <{list_of_clock_names}>)+



#------------------------------
# Clock Properties
#------------------------------
# POSTPLACE must be set in Innovus after placement and in Tempus/Voltus before loading SDC file


if {![info exists POSTPLACE]} {
  # Intra-clock uncertainty
#  set setupUncty     <value>
#  set holdUncty      <value>

  # Inter-clock uncertainty
#  set c2c_setupUncty  <value>
#  set c2c_holdUncty   <value>

#  set_clock_transition <value>  [-rise] [-fall] [-min] [-max] <clock>+
#  set_ideal_network    [-no_propagate] <port|pin|hpin|hnet>

} else {
  # Intra-clock uncertainty

#  set setupUncty     <value>
#  set holdUncty      <value>

  # Inter-clock uncertainty
#  set c2c_setupUncty  <value>
#  set c2c_holdUncty   <value>

# set_propagated_clock [-help] <pin_clock_list>  

# reset_ideal_network  <port|pin|hpin|hnet>  
}

# Set intra-clock uncertainty
#set_clock_uncertainty  -setup $setupUncty  [get_clocks *CLK*]
#set_clock_uncertainty  -setup $setupUncty  [get_clocks *CKG*]

#set_clock_uncertainty  -hold  $holdUncty   [get_clocks *CLK*]
#set_clock_uncertainty  -hold  $holdUncty   [get_clocks *CKG*]



# Set inter-clock uncertainty within groups (clock paths between groups are async)
# Use lists created when defining groups 

proc SetGroupUncertainty { clock_group_list } {
  global c2c_setupUncty
  global c2c_holdUncty

  set i [llength $clock_group_list]
  for { set a 0 } { $a < $i } { incr a } {
    set clk_a [lindex $clock_group_list $a]
    for { set b 0 } { $b < $i } { incr b } {
      set clk_b [lindex $clock_group_list $b]
      if { $clk_a != $clk_b } {
        set_clock_uncertainty  -setup $c2c_SetupUncty -from [get_clock $clk_a]  -to [get_clock $clk_b]
        set_clock_uncertainty  -hold  $c2c_HoldUncty  -from [get_clock $clk_a]  -to [get_clock $clk_b]
      }
    }
  }
}

# Call procedure for each group with synchronous clocks (defined in the clock groups section
#SetGroupUncertainty $clock_group_list



# Set max delays between async clocks that have a path between them (grouped with the -async 
# This is mostly used to constrain CDC FIFOs 

set clkPairsMaxDly "
  {CLK_name_a    CLK_name_b  <period_value> } \
  ...                                         \
  {CLK_name_y    CLK_name_z  <period_value> } \
  "

#foreach pair $clkPairsMaxDly {
#  set clka   [lindex $pair 0]
#  set clkb   [lindex $pair 1]
#  set period [lindex $pair 2]

#  set_max_delay [expr 0.8 * $period] -from [get_clocks $clka] -to [get_clocks $clkb]
#  set_max_delay [expr 0.8 * $period] -from [get_clocks $clkb] -to [get_clocks $clka]

#  set_false_path -hold -from [get_clocks $clka] -to [get_clocks $clkb]
#  set_false_path -hold -from [get_clocks $clkb] -to [get_clocks $clka]
}


#------------------------------
# Path Exceptions
#------------------------------

# set_multicycle_path [-help] <number_of_cycles> [-comment <string>] \
#                     [-setup | hold ]  [-fall | -rise]                                                        \
#                     [-from <from_list>       | -rise_from <from_list>        | -fall_from <from_list>      ] \
#                     [-to <to_list]>          | -rise_to <to_list>            | -fall_to <to_list]>         ] \
#                     [-through <through_list> | -rise_through <through_list>  | -fall_through <through_list>] \
#                     [-start  | -end ]

# set_false_path  [-help] [-comment <string>] \
#                 [-setup | -hold ] [-fall | -rise ]                                                      \
#                 [-from <from_list>       | -rise_from <from_list>       | -fall_from <from_list>]       \
#                 [-to <to_list]>          | -rise_to <to_list>           | -fall_to <to_list]>   ]       \
#                 [-through <through_list> | -fall_through <through_list> | -rise_through <through_list>] 
#


#------------------------------
# Timing Exceptions
#------------------------------

#set_disable_timing [-help] <object_list> [-from <pin_name> -to <pin_name>]

#<object_list>  # List of instance, instance pin, library cell, library cell pin objects, collection of library arcs or collection of
                # timing arcs (string, required)

#------------------------------
# IO Timing Constraints
#------------------------------
# Use collections to group ports by direction and/or name
# On inout signals apply both input and output constraints

#
# Input Timing
# set_input_delay [-help] <delay_value> <port_or_pin_list> [-add_delay] [-clock <clock_name>] [-clock_fall] [-fall] \
#                 [-level_sensitive] [-max] [-min] [-network_latency_included] [-reference_pin <pin_name>] [-rise] [-source_latency_included]

# Input Load
# set_driving_cell [-help] <port_list> [-fall] [-from_pin <from_pin_name>] [-input_transition_fall <fall_slew_value>] \
#                  [-input_transition_rise <rise_slew_value>] -lib_cell <cell_name> [-library <library_name>] [-max] [-min] \
#                  [-multiply_by <factor>] [-no_design_rule] [-pin <pin_name>] [-rise]
#
# set_input_transition [-help] <transition_time> <port_list> [-fall] [-max] [-min] [-rise]


# Output Timing
#set_output_delay [-help] <delay_value> <port_or_pin_list> [-add_delay] [-clock <clock_name>] [-clock_fall] [-fall] \
#                 [-group_path <group_name>] [-level_sensitive] [-max] [-min] [-network_latency_included] [-reference_pin <pin_name>] \
#                 [-rise] [-source_latency_included]

# Output Load
# set_load [-help] <capacitance_value> <object_list> [-max] [-min] [-pin_load] [-subtract_pin_load] [-wire_load]










