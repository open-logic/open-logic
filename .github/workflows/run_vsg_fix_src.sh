#!/bin/bash

#Run VSG Linter (Fix) for src directory
dir=./src
files=$(find $dir -name "*.vhd")
vsg --filename $files --configuration ./lint/config/vsg_config.yml --junit ./lint/report/vsg_fix_src_junit.xml --fix_only ./lint/config/fix_only_config.yml --fix
