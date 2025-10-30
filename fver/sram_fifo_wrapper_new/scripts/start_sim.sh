#!/bin/bash

source ../../../common/ENVARS
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -input restore.tcl
xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -define ARM_UD_MODEL
