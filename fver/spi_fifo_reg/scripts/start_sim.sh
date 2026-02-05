!/bin/bash

source ../../../ENVARS

xrun -64bit \
     -timescale 1ns/1ps \
     +gui +access+rwc -sv \
     -DUNIT_DELAY \
     -DFUNCTIONAL \
     +define+USE_POWER_PINS \
     +nospecify \
     +nowarnNODNTW \
     -f ../scripts/xrun.f \
     -input spi_fifo_reg_top.tcl
     # -input self_check.tcl
