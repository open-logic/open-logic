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
class olo_fix_utils:

    @staticmethod
    def fix_to_integer(data : np.ndarray, format : FixFormat) -> np.ndarray:
        """
        Convert the given data to integer representation based on the FixFormat.
        In contrast to the cl_fix_to_integer function, this function does also for for
        WideFix data types.

        Args:
            data (np.ndarray): The data to be converted.
            format (FixFormat): The FixFormat of the data.
        Returns:
            np.ndarray: The converted integer data.
        """
        if type(data)==WideFix:
          return data.data
        else:
            return cl_fix_to_integer(data, format)
        
    @staticmethod
    def fix_format_from_string(format_str : str) -> FixFormat:
        """
        Convert a string representation of a FixFormat to a FixFormat object.
        Args:
            format_str (str): The string representation of the FixFormat.
        Returns:
            FixFormat: The corresponding FixFormat object.
        """
        format_str = format_str.strip("()").replace(" ", "")
        a, b, c = map(int, format_str.split(","))
        return FixFormat(a, b, c)
    
    @staticmethod
    def plot_a_b_err(a : np.ndarray, b : np.ndarray, show : bool = True,
                     a_name : str = "a", b_name : str = "b", plot_error : bool = True) -> None:
        """
        Plot the a data, b data, and optionally the difference (a-b).

        Args:
            a (np.ndarray): The first data array to plot.
            b (np.ndarray): The second data array to plot.
            show (bool): If True, display the plot. Defaults to True.
            a_name (str): Name for the first data array in the plot title. Defaults to "a".
            b_name (str): Name for the second data array in the plot title. Defaults to "b".
            plot_error (bool): If True, plot the error (a-b). Defaults to True.
        """
        fig, axes = plt.subplots(2 if plot_error else 1, 1, figsize=(8, 10))  # Adjust number of subplots based on plot_error

        if not plot_error:
            axes = [axes]  # Ensure axes is always a list for consistency

        # First plot: Input vs Output Data
        ax1 = axes[0]
        ax1.plot(a, label=a_name, color="blue")  # Plot in_data in blue
        ax1.plot(b, label=b_name, color="red")  # Plot out_data in red
        ax1.set_title("Data")  # Set the title
        ax1.set_xlabel("Sample")  # Set the x-axis label
        ax1.set_ylabel("Value")  # Set the y-axis label
        ax1.legend()  # Add a legend

        # Second plot: Error (if enabled)
        if plot_error:
            err = a - b
            ax2 = axes[1]
            ax2.plot(err, label=f"Error ({a_name} - {b_name})", color="green")  # Plot err in green
            ax2.set_title("Difference")  # Set the title
            ax2.set_xlabel("Sample")  # Set the x-axis label
            ax2.set_ylabel("Difference Value")  # Set the y-axis label
            ax2.legend()  # Add a legend

        plt.tight_layout()  # Adjust layout to prevent overlap
        if show:
            plt.show()