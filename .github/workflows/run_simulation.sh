#!/bin/bash

#Run simulations
cd ./sim
python3 run.py --xunit-xml sim_report.xml -p 16
