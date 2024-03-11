from google.cloud import storage
import json
import os
from enum import Enum
import subprocess
import datetime

class BatgeColor(Enum):
    GREEN = "green"
    RED = "red"
    ORANGE = "orange"
    GREY = "lightgrey"
    BLUE = "blue"

class BatgeFolder(Enum):
    COVERAGE = "coverage"
    ISSUES = "issues"


def create_batge(text : str, value : str, color : BatgeColor, folder : BatgeFolder, filename : str):
    BUCKET_NAME = "open-logic-badges"
    CREDENTIALS_FILE = os.getenv("GCS_FILE")

    storage_client = storage.Client.from_service_account_json(CREDENTIALS_FILE)
    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(f"{folder.value}/{filename}.json")

    batch = {
        "schemaVersion": 1,
        "label": text,
        "message": value,
        "color": color.value
    }

    blob.upload_from_string(json.dumps(batch), predefined_acl='publicRead')

def create_coverage_batge(entity : str, value : float):
    color = BatgeColor.RED
    if value > 98.0:
        color = BatgeColor.GREEN
    elif value > 90.0:
        color = BatgeColor.ORANGE
    create_batge("statement coverage", f"{value:.1f}%", color, BatgeFolder.COVERAGE, entity)

def create_coverage_version_batge():
    #Hash Batge
    hash = subprocess.check_output("git log -1 --pretty=format:%h", shell=True, encoding="utf-8")
    create_batge("last coverage git-hash", hash, BatgeColor.BLUE, BatgeFolder.COVERAGE, "version")

    #Date Batge
    date = datetime.date.today()
    date_str = date.strftime("%d-%b-%Y")
    create_batge("last coverage date", date_str, BatgeColor.BLUE, BatgeFolder.COVERAGE, "date")


def create_issues_batge(entity : str, count : int, potential_bugs : bool, confirmed_bugs : bool):
    color = BatgeColor.RED
    if not confirmed_bugs:
        if not potential_bugs:
            color = BatgeColor.GREEN
        else:
            color = BatgeColor.ORANGE
    create_batge("issues", str(count), color, BatgeFolder.ISSUES, entity)
