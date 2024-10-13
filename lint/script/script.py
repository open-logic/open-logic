import os

# Define the directory to search
DIR = '../..'

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
all_files = " ".join(vhd_files_list)
result = os.system(f'vsg -c ../config/vsg_config.yml -f {all_files}')
if result != 0:
    print(f"Error: Linting of normal VHDL files failed - check report")
    #break

all_files = " ".join(vc_files_list) 
result = os.system(f'vsg -c ../config/vsg_config.yml ../config/vsg_config_overlay_vc.yml  -f {all_files}')
if result != 0:
    print(f"Error: Linting of normal Verification Component VHDL files failed - check report")
    #break


