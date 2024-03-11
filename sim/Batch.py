from google.cloud import storage
import json
import os
from enum import Enum
import subprocess
import datetime

class BatchColor(Enum):
    GREEN = "green"
    RED = "red"
    ORANGE = "orange"
    GREY = "lightgrey"
    BLUE = "blue"

class BatchFolder(Enum):
    COVERAGE = "coverage"
    ISSUES = "issues"


def create_batch(text : str, value : str, color : BatchColor, folder : BatchFolder, filename : str):
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

def create_coverage_batch(entity : str, value : float):
    color = BatchColor.RED
    if value > 98.0:
        color = BatchColor.GREEN
    elif value > 90.0:
        color = BatchColor.ORANGE
    create_batch("statement coverage", f"{value:.1f}%", color, BatchFolder.COVERAGE, entity)

def create_coverage_version_batch():
    #Hash Batch
    hash = subprocess.check_output("git log -1 --pretty=format:%h", shell=True, encoding="utf-8")
    create_batch("last coverage git-hash", hash, BatchColor.BLUE, BatchFolder.COVERAGE, "version")

    #Date Batch
    date = datetime.date.today()
    date_str = date.strftime("%d-%b-%Y")
    create_batch("last coverage date", date_str, BatchColor.BLUE, BatchFolder.COVERAGE, "date")


def create_issues_batch(entity : str, count : int, potential_bugs : bool, confirmed_bugs : bool):
    color = BatchColor.RED
    if not confirmed_bugs:
        if not potential_bugs:
            color = BatchColor.GREEN
        else:
            color = BatchColor.ORANGE
    create_batch("issues", str(count), color, BatchFolder.ISSUES, entity)
