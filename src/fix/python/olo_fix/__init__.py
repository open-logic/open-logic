import sys
import os
import glob
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../../3rdParty/en_cl_fix/bittrue/models/python")))


# Dynamically import all modules in the current directory
# Allos importing modules as "from olo_fix import olo_fix_sub" instead of "from olo_fix.olo_fix_sub import olo_fix_sub"
module_dir = os.path.dirname(__file__)
module_files = glob.glob(os.path.join(module_dir, "*.py"))
module_names = [os.path.basename(f)[:-3] for f in module_files if os.path.isfile(f) and not f.endswith("__init__.py")]

for module_name in module_names:
    exec(f"from .{module_name} import {module_name}")