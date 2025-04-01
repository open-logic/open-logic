# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from prettytable import PrettyTable
from typing import Dict

class ResourceResults:

    def __init__(self):
        self.results = {}
        self.all_fields = ["Config"]

    def add_results(self, config_name : str, results : Dict):
        # Add results
        self.results[config_name] = results

        # Update fields
        for field in results.keys():
            if field not in self.all_fields:
                self.all_fields.append(field)

    def get_table(self):
        # Create table
        table = PrettyTable()
        table.field_names = self.all_fields

        # Add data
        for config, results in self.results.items():
            row = [config]
            for field in self.all_fields[1:]:
                row.append(results.get(field, "-"))
            table.add_row(row)

        return table
