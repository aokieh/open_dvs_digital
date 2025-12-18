#!/bin/bash

source ../../../common/ENVARS
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -input restore.tcl
xrun -64bit \
     -timescale 1ns/1ps \
     +gui +access+rwc -sv \
     -DUNIT_DELAY \
     -DFUNCTIONAL \
     +define+USE_POWER_PINS \
     +nospecify \
     +nowarnNODNTW \
     -f ../scripts/xrun.f \
     -input sync_fifo_top.tcl
     # -input self_check.tcl

