#!/bin/bash

#Run VSG Linter (Check) for doc directory
dir=./doc
files=$(find $dir -name "*.vhd")
vsg --filename $files --configuration ./lint/config/vsg_config.yml --junit ./lint/report/vsg_check_doc_junit.xml --all_phases
