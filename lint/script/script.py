import os
import argparse

# Change directory to the script directory
os.chdir(os.path.dirname(os.path.realpath(__file__)))

# Detect arguments
parser = argparse.ArgumentParser(description='Lint all VHDL files in the project')
parser.add_argument('--debug', action='store_true', help='Lint files one by one and stop on any errors')
parser.add_argument('--syntastic', action='store_true', help='Output in syntastic format')

args = parser.parse_args()

# Define the directory to search
DIR = '../..'

# Not linted files
NOT_LINTED = ["RbExample.vhd"] # Docmentation example, incomplete VHDL
NOT_LINTED_DIR = ["../../3rdParty/"] # 3rd party libraries

def root_is_vc(root):
    return root.endswith('test/tb') or root.endswith('test\\tb')

def find_normal_vhd_files(directory):
    vhd_files = []
    for root, _, files in os.walk(directory):
        # Skip directories that are not relevant (including subdirectories)
        if any(root.startswith(not_linted) for not_linted in NOT_LINTED_DIR):
            continue

        #Lint files
        for file in files:
            # Skip VC files
            if root_is_vc(root):
                continue
            # Skip non VHD files
            if not file.endswith('.vhd'):
                continue
            # Skip not linted files
            if file in NOT_LINTED:
                continue
            #Append file
            vhd_files.append(os.path.abspath(os.path.join(root, file)))
    return vhd_files

def find_vc_vhd_files(directory):
    vhd_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            # Only add VC files
            if root_is_vc(root):
                vhd_files.append(os.path.abspath(os.path.join(root, file)))
    return vhd_files

# Configure output format
otutput_format = "-of vsg"
if args.syntastic:
    otutput_format = "-of syntastic"


# Get the list of .vhd files
vhd_files_list = find_normal_vhd_files(DIR)
vc_files_list = find_vc_vhd_files(DIR)

print("Normal VHDL Files")
print("\n".join(vhd_files_list))
print()
print("VC VHDL Files")
print("\n".join(vc_files_list))
print()
print("Start Linting")

error_occurred = False

# Execute linting for normal VHD files
if args.debug:
    for file in vhd_files_list:
        print(f"Linting {file}: Normal Config")
        result = os.system(f'vsg -c ../config/vsg_config.yml -f {file} {otutput_format}')
        if result != 0:
            raise Exception(f"Error: Linting of {file} failed - check report")
else:
    all_files = " ".join(vhd_files_list)
    result = os.system(f'vsg -c ../config/vsg_config.yml -f {all_files} --junit ../report/vsg_normal_vhdl.xml --all_phases {otutput_format}')
    if result != 0:
        error_occurred = True

# Execute linting for VC VHD files
if args.debug:
    for file in vc_files_list:
        print(f"Linting {file}: VC Config")
        result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml -f {file} {otutput_format}')
        if result != 0:
            raise Exception(f"Error: Linting of {file} failed - check report")
else:
    all_files = " ".join(vc_files_list) 
    result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml -f {all_files} --junit ../report/vsg_vc_vhdl.xml --all_phases {otutput_format}')
    if result != 0:
        error_occurred = True

if error_occurred:
    raise Exception(f"Error: Linting of VHDL files failed - check report")

# Print success message
print("All VHDL files linted successfully")



