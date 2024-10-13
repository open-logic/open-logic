import os
import argparse

# Change directory to the script directory
os.chdir(os.path.dirname(os.path.realpath(__file__)))

# Detect arguments
parser = argparse.ArgumentParser(description='Lint all VHDL files in the project')
parser.add_argument('--debug', action='store_true', help='Lint files one by one and stop on any errors')

args = parser.parse_args()

# Define the directory to search
DIR = '../..'

# Not linted files
NOT_LINTED = ["olo_intf_i2c_master.vhd"]

def find_normal_vhd_files(directory):
    vhd_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            # Skip Package Files
            if 'pkg' in file:
                continue
            # Skip VC files
            if file.endswith('vc.vhd'):
                continue
            # Skip non VHD files
            if not file.endswith('.vhd'):
                continue
            # Skip not linted files
            if file in NOT_LINTED:
                continue
            #Append file
            vhd_files.append(os.path.join(root, file))
    return vhd_files

def find_vc_vhd_files(directory):
    vhd_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            # Skip VC files
            if file.endswith('_vc.vhd'):
                vhd_files.append(os.path.join(root, file))
    return vhd_files

# Get the list of .vhd files
vhd_files_list = find_normal_vhd_files(DIR)
vc_files_list = find_vc_vhd_files(DIR)

# Execute linting for normal VHD files
if args.debug:
    for file in vhd_files_list:
        print(f"Linting {file}")
        result = os.system(f'vsg -c ../config/vsg_config.yml -f {file}')
        if result != 0:
            raise Exception(f"Error: Linting of {file} failed - check report")
else:
    all_files = " ".join(vhd_files_list)
    result = os.system(f'vsg -c ../config/vsg_config.yml -f {all_files} --junit ../report/vsg_normal_vhdl.xml --all_phases')
    if result != 0:
        raise Exception(f"Error: Linting of normal VHDL files failed - check report")

# Execute linting for VC VHD files
if args.debug:
    for file in vc_files_list:
        print(f"Linting {file}")
        result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml -f {file}')
        if result != 0:
            raise Exception(f"Error: Linting of {file} failed - check report")
else:
    all_files = " ".join(vc_files_list) 
    result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml  -f {all_files} --junit ../report/vsg_vc_vhdl.xml --all_phases')
    if result != 0:
        raise Exception(f"Error: Linting of normal Verification Component VHDL files failed - check report")


