#!/bin/bash

# Move needed files
mv *tcl ../scripts/
mv *svcf ../scripts/

# Remove unwanted xcelium files
rm -rf *
rm -rf .simvision

# Move back needed files
mv ../scripts/*tcl .
mv ../scripts/*svcf .
