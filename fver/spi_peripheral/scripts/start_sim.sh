#!/bin/bash

# source ../../../ENVARS
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -sv
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +access+rwc

source ../../../ENVARS

xrun -64bit \
     -timescale 1ns/1ps \
     +gui +access+rwc -sv \
     -DUNIT_DELAY \
     -DFUNCTIONAL \
     +define+USE_POWER_PINS \
     +nospecify \
     +nowarnNODNTW \
     -f ../scripts/xrun.f 
    #  -input regfile.tcl
     # -input self_check.tcl
