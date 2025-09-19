#!/bin/bash

source ../../../ENVARS
xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc -sv
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +access+rwc