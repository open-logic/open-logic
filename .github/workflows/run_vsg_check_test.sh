#!/bin/bash

#Run VSG Linter (Check) for test directory
dir=./test
files=$(find $dir -name "*.vhd")
vsg --filename $files --configuration ./lint/config/vsg_config.yml --junit ./lint/report/vsg_check_test_junit.xml --all_phases
