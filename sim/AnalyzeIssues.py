#Usage: python3 AnalyzeIssues.py <github-token>
########################################################################################################################
# Imports
########################################################################################################################
import os
import json
from github import Github
import sys
from glob import glob
from enum import Enum
from Badge import create_issues_badge

########################################################################################################################
# Types
########################################################################################################################
class Labels(Enum):
    POTENTIAL_BUG = "potential-bug"
    CONFIRMED_BUG = "confirmed-bug"

########################################################################################################################
# Script
########################################################################################################################
github_token = sys.argv[1]

# Authenticate to GitHub
g = Github(github_token)

# Specify the repository owner, repository name, and tag
repository_owner = "obruendl"
repository_name = "open-logic"

# Get the repository
repo = g.get_repo(f"{repository_owner}/{repository_name}")

# Get a list of all entity names
FileNames = files = glob('../src/**/*.vhd', recursive=True)
EntityNames = [f.split("/")[-1].replace(".vhd", "") for f in FileNames]

# Analyze issues for all entities
for entity in EntityNames:
    entity_issues = repo.get_issues(labels=[entity]).totalCount
    potential_bugs = repo.get_issues(labels=[entity, Labels.POTENTIAL_BUG.value]).totalCount
    confirmed_bugs = repo.get_issues(labels=[entity, Labels.CONFIRMED_BUG.value]).totalCount
    create_issues_badge(entity, entity_issues, potential_bugs > 0, confirmed_bugs > 0)
    print(f"{entity:40} issues:{entity_issues:3} potential:{potential_bugs:3} confirmed:{confirmed_bugs:3}")


