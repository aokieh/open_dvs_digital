!/bin/bash

source ../../../ENVARS

#xrun -64bit \
#    -timescale 1ns/1ps \
#    -f ../scripts/xrun.f \
#    +gui +access+rwc -sv \
#    -DUNIT_DELAY \
#    -DFUNCTIONAL \
#    +define+POWER_PINS_V2 \
#    +nospecify \

xrun -64bit \
     -timescale 1ns/1ps \
     +gui +access+rwc -sv \
     -DUNIT_DELAY \
     -DFUNCTIONAL \
     +define+USE_POWER_PINS \
     +nospecify \
     +nowarnNODNTW \
     -f ../scripts/xrun.f

#    -v /LinuxRAID/home/aokieh1/projects/digital_top_hardened_macro/dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
    

# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -sv -DUNIT_DELAY -DFUNCTIONAL
# +define+POWER_PINS_V2 \
#    ../dependencies/pdks/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v \
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -sv -DFUNCTIONAL
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -sv
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +access+rwc
