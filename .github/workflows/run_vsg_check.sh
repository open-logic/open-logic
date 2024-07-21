#!/bin/bash

#Run VSG Linter (Check)
dir=.
files=$(find $dir -name "*.vhd")
vsg --filename $files --configuration ./lint/config/vsg_config.yml --junit ./lint/report/vsg_check_junit.xml --all_phases
