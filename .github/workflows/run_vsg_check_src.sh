#!/bin/bash

#Run VSG Linter (Check) for src directory
dir=./src
files=$(find $dir -name "*.vhd")
vsg --filename $files --configuration ./lint/config/vsg_config.yml --junit ./lint/report/vsg_check_src_junit.xml --all_phases
