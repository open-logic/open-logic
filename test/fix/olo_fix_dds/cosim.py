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

    # Samples per channel (reduced for many channels to keep the simulation time reasonable, long
    # for plotting to get a good FFT resolution)
    SAMPLES = (max(1200 // Channels_g, 40) if cosim_mode else 2**14)

    #Generate inputs per channel
    # - CH0: Constant frequency and phase (odd frequency, used for the FFT)
    # - CH1: Constant frequency, varying phase
    # - CH2: Varying frequency, constant phase
    # - CH3: Varying frequency and phase
    # - Others: Random step/offset that change at runtime
    # Varying values follow square patterns with different periods (< 500 samples, hence all edges are
    # visible in the plots).
    # A single restart is applied to CH3 (only if Channels_g > 3) in
    # the middle of the stream. The model has no restart input, a restart is modeled by calling
    # reset().
    restart_ch_idx = 3
    restart_sample = min(250, SAMPLES*3//8)
    rng = np.random.default_rng(seed=Channels_g)
    n = np.arange(SAMPLES)
    step_const = 0.0123456789
    offset_const = 0.3
    def square(low, high, period):
        # Toggles between low and high with the given period in samples (50% duty cycle)
        return np.where((n*2//period) % 2 == 0, low, high)
    step_vary_a = square(0.01, 0.09, 160)
    step_vary_b = square(0.1, 0.3, 230)
    offset_vary_a = square(0.05, 0.95, 300)
    offset_vary_b = square(0.2, 0.8, 110)
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
        restart = np.zeros(SAMPLES)
        if ch == restart_ch_idx:
            restart[restart_sample] = 1.0
        step_ch.append(cl_fix_from_real(step, PhaseFmt_g, FixSaturate.Sat_s))
        offset_ch.append(cl_fix_from_real(offset, PhaseFmt_g, FixSaturate.Sat_s))
        restart_ch.append(restart)

    #Calculate (the model is single-channel, hence one instance per channel)
    sin_ch = []
    cos_ch = []
    for ch in range(Channels_g):
        dut = olo_fix_dds(PhaseFmt_g, OutFmt_g, Round_g)
        if ch == restart_ch_idx:
            # A restart sets the accumulator to zero before the restarted sample is processed, which is
            # what reset() does. Hence the stream is processed in two parts with reset() in between.
            part_a = slice(0, restart_sample)
            part_b = slice(restart_sample, SAMPLES)
            sin_a, cos_a = dut.next(step_ch[ch][part_a], offset_ch[ch][part_a])
            dut.reset()
            sin_b, cos_b = dut.next(step_ch[ch][part_b], offset_ch[ch][part_b])
            out_sin = np.concatenate((sin_a, sin_b))
            out_cos = np.concatenate((cos_a, cos_b))
        else:
            out_sin, out_cos = dut.process(step_ch[ch], offset_ch[ch])
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
        # Time domain (first 4 channels, zoomed in to the first 500 samples to keep the waveforms visible)
        plot_ch = range(min(Channels_g, 4))
        zoom = slice(0, 500)
        plots = {"Step [rotations] (first 500 samples)" : {f"CH{ch}" : step[ch::Channels_g][zoom] for ch in plot_ch},
                 "Offset [rotations] (first 500 samples)" : {f"CH{ch}" : offset[ch::Channels_g][zoom] for ch in plot_ch}}
        for ch in plot_ch:
            plots[f"CH{ch} Output (first 500 samples)"] = {"Sine" : out_sin[ch::Channels_g][zoom],
                                                            "Cosine" : out_cos[ch::Channels_g][zoom]}
        olo_fix_plots.plot_subplots(plots, show=False)

        # Spectrum of CH0 (complex signal, Kaiser window with high sidelobe suppression)
        cplx = out_cos[0::Channels_g] + 1j*out_sin[0::Channels_g]
        olo_fix_plots.plot_spectrum({"CH0" : cplx}, window=np.kaiser(SAMPLES, 20), ref_level=dut.peak,
                                    title=f"CH0 Spectrum (Step = {step_const} rotations, OutFmt = {OutFmt_g})",
                                    ylim=(-200, 10))

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
        "Round_g": "NonSymPos_s"
    }
    cosim(generics=generics, cosim_mode=False)
