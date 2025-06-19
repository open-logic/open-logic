# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
from prettytable import PrettyTable
from typing import Dict

class ResourceResults:
    """
    A class to collect and manage resource results from synthesis tools.
    
    The resources are organized according to the name used in the synthesis tool becasue resource types differ
    between tools.
    """

    def __init__(self):
        """
        Constructor
        Initializes an empty results dictionary and a list of all fields.
        """
        self.results = {}
        self.all_fields = ["Config"]

    def add_results(self, config_name : str, results : Dict):
        """
        Add results for a specific configuration.

        :param config_name: The name of the configuration.
        :param results: A dictionary containing the results for the configuration (key: resource type, value: count).
        """
        # Add results
        self.results[config_name] = results

        # Update fields
        for field in results.keys():
            if field not in self.all_fields:
                self.all_fields.append(field)

    def get_table(self) -> PrettyTable:
        """
        Generate a PrettyTable with the collected results.

        :return: A PrettyTable object containing the results.
        """
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
