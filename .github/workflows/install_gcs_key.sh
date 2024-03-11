#!/bin/bash

#Run Unpack secret
sudo apt-get update
sudo apt-get install openssl
openssl enc -k $GCS_PASSPHRASE -d -aes-256-cbc -in ./.github/workflows/open-logic-badges.json.gpg -out ~/gcs.json 
export GCS_FILE=~/gcs.json
