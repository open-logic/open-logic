#Usage: python3 AnalyzeCoverage.py [--badges]
########################################################################################################################
# Imports
########################################################################################################################
import os
import json
from Badge import create_coverage_version_badge, create_coverage_badge, create_branch_badge
import sys

########################################################################################################################
# Parse Arguments
########################################################################################################################
UPDATE_BADGES = False
if "--badges" in sys.argv:
    UPDATE_BADGES = True

########################################################################################################################
# Types
########################################################################################################################
class Entity:
    def __init__(self):
        self.name = None
        self.statements = None
        self.branches = 100.0 #Default 100%, if there are no branches the default is never modified

    def parse_name_line(self, line : str):
        filename = line.split("/")[-1]
        self.name = filename.split(".")[0]

    def parse_statement_line(self, line : str):
        parts = line.split()
        self.statements = float(parts[-1].replace("%", ""))

    def parse_branch_line(self, line : str):
        parts = line.split()
        self.branches = float(parts[-1].replace("%", ""))


########################################################################################################################
# Script
########################################################################################################################
#*** Parse Coverage File from Modelsim ***
os.system("vcover report -byfile -nocomment coverage_data > coverage_report.txt")
fd = open("coverage_report.txt")
entities = []
for line in fd.readlines():
    if "File:" in line:
        entity = Entity()
        entity.parse_name_line(line)
    if "Branches" in line:
        entity.parse_branch_line(line)
    if "Statements" in line:
        entity.parse_statement_line(line)
        entities.append(entity)

#*** Generate Output ***
print("Entity:                        Statements Branches")
for entity in entities:
    print(f"{entity.name:25}: {entity.statements:9}% {entity.branches:9}%")
    if UPDATE_BADGES:
        create_coverage_badge(entity.name, entity.statements)
        create_branch_badge(entity.name, entity.branches)
if UPDATE_BADGES:
    create_coverage_version_badge()





