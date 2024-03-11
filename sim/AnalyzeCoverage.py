#Usage: python3 AnalyzeCoverage.py [--badges]
########################################################################################################################
# Imports
########################################################################################################################
import os
import json
from Batge import create_coverage_version_batge, create_coverage_batge
import sys

########################################################################################################################
# Parse Arguments
########################################################################################################################
UPDATE_BATGES = False
if "--batges" in sys.argv:
    UPDATE_BATGES = True

########################################################################################################################
# Types
########################################################################################################################
class Entity:
    def __init__(self):
        self.name = None
        self.coverage = None

    def parse_name_line(self, line : str):
        filename = line.split("/")[-1]
        self.name = filename.split(".")[0]

    def parse_coverage_line(self, line : str):
        parts = line.split()
        self.coverage = float(parts[-1].replace("%", ""))

    def get_batch_json(self):
        color = "red"
        if self.coverage > 98.0:
            color = "green"
        elif self.coverage > 90.0:
            color = "orange"
        batch = {
            "schemaVersion": 1,
            "label": "statement coverage",
            "message": f"{self.coverage}%",
            "color": color
        }
        return json.dumps(batch)

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
    if "Statements" in line:
        entity.parse_coverage_line(line)
        entities.append(entity)

#*** Generate Output ***
for entity in entities:
    print(f"{entity.name:40}: {entity.coverage}%")
    if UPDATE_BATGES:
        create_coverage_batge(entity.name, entity.coverage)
if UPDATE_BATGES:
    create_coverage_version_batge()





