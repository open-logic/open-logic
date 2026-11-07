# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025-2026 by Oliver Bründler
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
    def plot_subplots(data_dict: dict, show: bool = True) -> None: # pragma: no cover - testing plots automated is difficult
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

        fig.subplots_adjust(hspace=0.5)  # Adjust vertical spacing between subplots
        if show:
            plt.show()

    @staticmethod
    def plot_spectrum(signals: dict, window: np.ndarray = None, freq_scale: float = 1.0, ref_level: float = None,
                      overlays: dict = None, title: str = "Spectrum", freq_unit: str = "Fs",
                      ylim: tuple = (-150, 10), show: bool = True) -> None: # pragma: no cover - testing plots automated is difficult
        """
        Plot the magnitude spectrum of one or more signals, optionally with overlays (e.g. theoretical response
        or specification mask).

        Real signals are plotted one-sided (0 ... Fs/2), complex signals two-sided (-Fs/2 ... Fs/2).

        Args:
            signals (dict): Name (key) and time-domain data (value) pairs. All signals must have the same length.
            window (np.ndarray): Window applied before the FFT. None means rectangular. The window choice depends
                                 on the signal and is therefore left to the caller.
            freq_scale (float): Scale factor for the frequency axis. The default 1.0 gives frequencies normalized to
                                the sample rate of the signals.
            ref_level (float): Amplitude corresponding to 0 dBFS. None normalizes to the peak of the first signal.
            overlays (dict): Name (key) and (freq, mag_db) tuple (value) pairs, plotted as dashed lines. Frequencies
                             must be given in the same unit as the scaled frequency axis.
            title (str): Title of the plot.
            freq_unit (str): Unit shown on the frequency axis label.
            ylim (tuple): Limits of the magnitude axis in dB.
            show (bool): If True, display the plot. Defaults to True.
        """
        plt.figure(figsize=(10, 5))
        norm = None
        for name, values in signals.items():
            values = np.asarray(values)
            win = np.ones(len(values)) if window is None else window
            if np.iscomplexobj(values):
                spec = np.abs(np.fft.fftshift(np.fft.fft(values*win)))
                freq = np.fft.fftshift(np.fft.fftfreq(len(values)))
            else:
                spec = np.abs(np.fft.rfft(values*win))
                freq = np.fft.rfftfreq(len(values))
                spec[1:] *= 2 # One-sided: Account for energy in negative frequencies (DC is not doubled)
            if norm is None:
                norm = np.max(spec) if ref_level is None else ref_level*np.sum(win)
            plt.plot(freq*freq_scale, 20*np.log10(spec/norm + 1e-20), label=name)
        for name, (freq, mag_db) in (overlays or {}).items():
            plt.plot(freq, mag_db, "--", label=name)
        plt.title(title)
        plt.xlabel(f"Frequency [{freq_unit}]")
        plt.ylabel("Magnitude [dB]" if ref_level is None else "Magnitude [dBFS]")
        plt.ylim(*ylim)
        plt.grid(True)
        plt.legend()
        if show:
            plt.show()
