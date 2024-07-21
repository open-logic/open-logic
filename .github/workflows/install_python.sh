#!/bin/bash

# Install Python packages (Vunit_hdl)
pip3 install vunit_hdl PyGithub google-cloud-storage

# Install Python packages (VSG)
pip3 install vsg==3.25.0 --use-pep517
