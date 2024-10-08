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
for vhd_file in vhd_files_list:
    
    result = os.system(f'vsg -c ../config/vsg_config.yml -f {vhd_file}')
    if result != 0:
        print(f"Error: Command failed for file {vhd_file}")
        break

# Execute linting for VC VHD files
for vhd_file in vc_files_list:
    
    result = os.system(f'vsg -c ../config/vsg_config.yml -f {vhd_file}')
    if result != 0:
        print(f"Error: Command failed for file {vhd_file}")
        break


