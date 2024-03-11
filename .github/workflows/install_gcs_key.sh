#!/bin/bash

#Run Unpack secret
gpg --quiet --batch --yes --decrypt --passphrase=$GCS_PASSPHRASE --output ~/gcs.json ./.github/workflows/open-logic-badges.json.gpg
export GCS_FILE=~/gcs.json
