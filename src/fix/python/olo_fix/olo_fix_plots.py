# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from en_cl_fix_pkg import *
import numpy as np
from matplotlib import pyplot as plt

# ---------------------------------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------------------------------
class olo_fix_plots:
    
    @staticmethod
    def plot_subplots(data_dict: dict, show: bool = True) -> None:
        """
        Plot multiple subplots based on a dictionary of dictionaries.

        Args:
            data_dict (dict): A dictionary where each key is the title of a subplot,
                              and the value is another dictionary containing name (key)
                              and data (value) pairs to plot.
            show (bool): If True, display the plot. Defaults to True.
        """
        # Create subplots based on the number of entries in data_dict
        num_subplots = len(data_dict)
        fig, axes = plt.subplots(num_subplots, 1, figsize=(8, 5 * num_subplots))  # Adjust height per subplot

        # Ensure axes is always iterable (even if there's only one subplot)
        if num_subplots == 1:
            axes = [axes]

        # Iterate over each subplot
        for ax, (title, data) in zip(axes, data_dict.items()):
            # Plot each data series in the current subplot
            for name, values in data.items():
                ax.plot(values, label=name)  # Plot the data with its label
            ax.set_title(title)  # Set the title of the subplot
            ax.set_xlabel("Sample")  # Set the x-axis label
            ax.set_ylabel("Value")  # Set the y-axis label
            ax.legend()  # Add a legend

        plt.tight_layout(pad=3.0)  # Adjust layout to prevent overlap
        if show:
            plt.show()