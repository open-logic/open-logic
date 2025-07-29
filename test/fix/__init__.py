import os
import importlib

# Get the current directory
current_dir = os.path.dirname(__file__)

# Recursively import all Python files in subdirectories
for root, dirs, files in os.walk(current_dir):
    for file in files:
        if file.endswith(".py") and file != "__init__.py":
            # Construct the module name relative to the package
            relative_path = os.path.relpath(os.path.join(root, file), current_dir)
            module_name = relative_path.replace(os.sep, ".")[:-3]  # Remove ".py" extension

            try:
                # Import the module dynamically
                importlib.import_module(f".{module_name}", package=__name__)
            except ImportError as e:
                print(f"Failed to import {module_name}: {e}")