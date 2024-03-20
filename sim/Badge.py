from google.cloud import storage
import json
import os
from enum import Enum
import subprocess
import datetime

class BadgeColor(Enum):
    GREEN = "green"
    RED = "red"
    ORANGE = "orange"
    GREY = "lightgrey"
    BLUE = "blue"

class BadgeFolder(Enum):
    COVERAGE = "coverage"
    BRANCHES = "branches"
    ISSUES = "issues"


def create_badge(text : str, value : str, color : BadgeColor, folder : BadgeFolder, filename : str):
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

def create_coverage_badge(entity : str, value : float):
    color = BadgeColor.RED
    if value > 90.0:
        color = BadgeColor.GREEN
    elif value > 95.0:
        color = BadgeColor.ORANGE
    create_badge("statement coverage", f"{value:.1f}%", color, BadgeFolder.COVERAGE, entity)

def create_branch_badge(entity : str, value : float):
    color = BadgeColor.RED
    if value > 90.0:
        color = BadgeColor.GREEN
    elif value > 95.0:
        color = BadgeColor.ORANGE
    create_badge("branch coverage", f"{value:.1f}%", color, BadgeFolder.BRANCHES, entity)

def create_coverage_version_badge():
    #Hash Batge
    hash = subprocess.check_output("git log -1 --pretty=format:%h", shell=True, encoding="utf-8")
    create_badge("last coverage git-hash", hash, BadgeColor.BLUE, BadgeFolder.COVERAGE, "version")

    #Date Batge
    date = datetime.date.today()
    date_str = date.strftime("%d-%b-%Y")
    create_badge("last coverage date", date_str, BadgeColor.BLUE, BadgeFolder.COVERAGE, "date")


def create_issues_badge(entity : str, count : int, potential_bugs : bool, confirmed_bugs : bool):
    color = BadgeColor.RED
    if not confirmed_bugs:
        if not potential_bugs:
            color = BadgeColor.GREEN
        else:
            color = BadgeColor.ORANGE
    create_badge("issues", str(count), color, BadgeFolder.ISSUES, entity)
