#!/bin/bash

#Run simulations
cd ./sim
echo $TEST_SECRET
python3 AnalyzeIssues.py $TEST_SECRET
