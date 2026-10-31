# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
# Import python packages
import sys
import os
import numpy as np
from matplotlib import pyplot as plt

#Import olo_fix
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../src/fix/python")))
from olo_fix import olo_fix_cosim, olo_fix_utils, olo_fix_dds, olo_fix_plots
from en_cl_fix_pkg import *

def cosim(output_path : str = None,
          generics : dict = None,
          cosim_mode : bool = True):

    #Parse Generics
    Channels_g = int(generics["Channels_g"])
    PhaseFmt_g = olo_fix_utils.fix_format_from_string(generics["PhaseFmt_g"])
    OutFmt_g = olo_fix_utils.fix_format_from_string(generics["OutFmt_g"])
    Round_g = FixRound[generics["Round_g"]]
    Saturate_g = FixSaturate[generics["Saturate_g"]]

    # Samples per channel (reduced for many channels to keep the simulation time reasonable, long
    # for plotting to get a good FFT resolution)
    SAMPLES = (max(1200 // Channels_g, 40) if cosim_mode else 2**14)

    #Generate inputs per channel
    # - CH0: Constant frequency and phase (odd frequency, used for the FFT)
    # - CH1: Constant frequency, varying phase
    # - CH2: Varying frequency, constant phase
    # - CH3: Varying frequency and phase
    # - Others: Random step/offset that change at runtime
    # Varying values follow sine patterns. Restarts are applied randomly to all channels except
    # CH0 (to keep its spectrum clean).
    rng = np.random.default_rng(seed=Channels_g)
    n = np.arange(SAMPLES)
    step_const = 0.0123456789
    offset_const = 0.3
    step_vary_a = 0.05 + 0.04*np.sin(2*np.pi*n/(SAMPLES/2))
    step_vary_b = 0.2 + 0.1*np.sin(2*np.pi*n/(SAMPLES/3))
    offset_vary_a = 0.5 + 0.45*np.sin(2*np.pi*n/(SAMPLES/3))
    offset_vary_b = 0.5 + 0.3*np.sin(2*np.pi*n/(SAMPLES/5))
    step_ch = []
    offset_ch = []
    restart_ch = []
    for ch in range(Channels_g):
        if ch == 0:
            step = np.full(SAMPLES, step_const)
            offset = np.full(SAMPLES, offset_const)
        elif ch == 1:
            step = np.full(SAMPLES, step_const*3)
            offset = offset_vary_a
        elif ch == 2:
            step = step_vary_a
            offset = np.full(SAMPLES, offset_const)
        elif ch == 3:
            step = step_vary_b
            offset = offset_vary_b
        else:
            step = np.full(SAMPLES, rng.uniform(0.0, 0.5))
            step[SAMPLES//2:] = rng.uniform(0.0, 1.0)
            offset = np.full(SAMPLES, rng.uniform(0.0, 1.0))
            offset[SAMPLES*3//4:] = rng.uniform(0.0, 1.0)
        restart = rng.uniform(0.0, 1.0, SAMPLES) < 0.03
        if ch == 0:
            restart[:] = False
        step_ch.append(cl_fix_from_real(step, PhaseFmt_g, FixSaturate.Sat_s))
        offset_ch.append(cl_fix_from_real(offset, PhaseFmt_g, FixSaturate.Sat_s))
        restart_ch.append(restart.astype(float))

    #Calculate (the model is single-channel, hence one instance per channel)
    sin_ch = []
    cos_ch = []
    for ch in range(Channels_g):
        dut = olo_fix_dds(PhaseFmt_g, OutFmt_g, Round_g, Saturate_g)
        out_sin, out_cos = dut.process(step_ch[ch], offset_ch[ch], restart_ch[ch])
        sin_ch.append(out_sin)
        cos_ch.append(out_cos)

    #Interleave
    step = np.array(step_ch).T.flatten()
    offset = np.array(offset_ch).T.flatten()
    restart = np.array(restart_ch).T.flatten()
    out_sin = np.array(sin_ch).T.flatten()
    out_cos = np.array(cos_ch).T.flatten()
    last = np.tile(np.arange(Channels_g) == Channels_g - 1, SAMPLES).astype(float)

    # Plot if enabled
    if not cosim_mode:
        # Time domain (first 4 channels, output zoomed in to keep the waveforms visible)
        plot_ch = range(min(Channels_g, 4))
        zoom = slice(0, 500)
        plots = {"Step [rotations]" : {f"CH{ch}" : step[ch::Channels_g] for ch in plot_ch},
                 "Offset [rotations]" : {f"CH{ch}" : offset[ch::Channels_g] for ch in plot_ch}}
        for ch in plot_ch:
            plots[f"CH{ch} Output (first 500 samples)"] = {"Sine" : out_sin[ch::Channels_g][zoom],
                                                            "Cosine" : out_cos[ch::Channels_g][zoom]}
        olo_fix_plots.plot_subplots(plots, show=False)

        # Spectrum of CH0 (complex signal, Kaiser window with high sidelobe suppression)
        cplx = out_cos[0::Channels_g] + 1j*out_sin[0::Channels_g]
        window = np.kaiser(SAMPLES, 20)
        spec = np.fft.fftshift(np.fft.fft(cplx*window))
        spec_db = 20*np.log10(np.abs(spec)/(dut.peak*np.sum(window)) + 1e-20)
        freq = np.fft.fftshift(np.fft.fftfreq(SAMPLES))
        plt.figure(figsize=(10, 5))
        plt.plot(freq, spec_db)
        plt.title(f"CH0 Spectrum (Step = {step_const} rotations, OutFmt = {OutFmt_g})")
        plt.xlabel("Frequency [Fs]")
        plt.ylabel("Magnitude [dBFS]")
        plt.ylim(-200, 10)
        plt.grid(True)
        plt.show()

    #Write Files
    if cosim_mode:
        writer = olo_fix_cosim(output_path)
        writer.write_cosim_file(step, PhaseFmt_g, "Step.fix")
        writer.write_cosim_file(offset, PhaseFmt_g, "Offset.fix")
        writer.write_cosim_file(restart, FixFormat(0, 1, 0), "Restart.fix")
        writer.write_cosim_file(out_sin, OutFmt_g, "Sin.fix")
        writer.write_cosim_file(out_cos, OutFmt_g, "Cos.fix")
        writer.write_cosim_file(last, FixFormat(0, 1, 0), "Last.fix")
    return True

if __name__ == "__main__":
    # Example usage
    generics = {
        "Channels_g": "4",
        "PhaseFmt_g": "(0, 0, 32)",
        "OutFmt_g": "(1, 0, 16)",
        "Round_g": "NonSymPos_s",
        "Saturate_g": "Sat_s"
    }
    cosim(generics=generics, cosim_mode=False)
