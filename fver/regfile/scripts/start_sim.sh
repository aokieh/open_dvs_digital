#!/bin/bash

source ../../../ENVARS
xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +gui +access+rwc
# xrun -64bit -timescale 1ns/1ps -f ../scripts/xrun.f +access+rwc