# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from .utils import named_config
import sys
import os

# Import for fix cosimulations
sys.path.append(os.path.join(os.path.dirname(__file__), '../../test'))
from fix import *

# ---------------------------------------------------------------------------------------------------
# Functionality
# ---------------------------------------------------------------------------------------------------

def add_fix_configs(olo_tb):
    """
    Add all fix testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """
    fix_vc_tb = 'olo_fix_vc_tb'
    tb = olo_tb.test_bench(fix_vc_tb)
    for S in ['0', '1']:
        for F in ['0', '61']: #Ensure numbeers > double precision (53 bits)
            named_config(tb, {'Fmt_g': f'({S},15,{F})', 'FileIn_g' : 'File.fix', 'FileOut_g' : 'File.fix'}, 
                            pre_config=olo_fix_vc.cosim.cosim)

    fix_abs_tb = 'olo_fix_abs_tb'
    tb = olo_tb.test_bench(fix_abs_tb)
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(0,8,4)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
        'AFile_g': 'A.fix',
        'ResultFile_g': 'Result.fix',
        'OpRegs_g': 1,
        'RoundReg_g': "YES",
        'SatReg_g': "YES"
    }
    cosim = olo_fix_abs.cosim.cosim
    # Different math
    for Round in ['NonSymPos_s', 'Trunc_s']:
        for Sat in ['Sat_s', 'None_s']:
            named_config(tb, default_generics  | {'Round_g': Round, 'Saturate_g': Sat},
                            pre_config=cosim)
    # Different register settings
    for OpRegs in [0, 4]:
        named_config(tb, default_generics | {'OpRegs_g': OpRegs}, pre_config=cosim)
    for RoundReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'RoundReg_g': RoundReg}, pre_config=cosim)
    for SatReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'SatReg_g': SatReg}, pre_config=cosim)

    fix_neg_tb = 'olo_fix_neg_tb'
    tb = olo_tb.test_bench(fix_neg_tb)
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(0,8,4)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
        'AFile_g': 'A.fix',
        'ResultFile_g': 'Result.fix',
        'OpRegs_g': 1,
        'RoundReg_g': "YES",
        'SatReg_g': "YES"
    }
    cosim = olo_fix_neg.cosim.cosim
    # Different math
    for Round in ['NonSymPos_s', 'Trunc_s']:
        for Sat in ['Sat_s', 'None_s']:
            named_config(tb, default_generics  | {'Round_g': Round, 'Saturate_g': Sat},
                            pre_config=cosim)
    # Different register settings
    for OpRegs in [0, 4]:
        named_config(tb, default_generics | {'OpRegs_g': OpRegs}, pre_config=cosim)
    for RoundReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'RoundReg_g': RoundReg}, pre_config=cosim)
    for SatReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'SatReg_g': SatReg}, pre_config=cosim)
        
    fix_resize_tb = 'olo_fix_resize_tb'
    tb = olo_tb.test_bench(fix_resize_tb)
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(0,4,4)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
        'AFile_g': 'A.fix',
        'ResultFile_g': 'Result.fix',
        'RoundReg_g': "YES",
        'SatReg_g': "YES"
    }
    cosim = olo_fix_resize.cosim.cosim
    # Different math
    for Round in ['NonSymPos_s', 'Trunc_s']:
        for Sat in ['Sat_s', 'None_s']:
            named_config(tb, default_generics  | {'Round_g': Round, 'Saturate_g': Sat},
                            pre_config=cosim)
    # Different register settings
    for RoundReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'RoundReg_g': RoundReg}, pre_config=cosim)
    for SatReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'SatReg_g': SatReg}, pre_config=cosim)

    fix_round_tb = 'olo_fix_round_tb'
    tb = olo_tb.test_bench(fix_round_tb)
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(1,9,4)',
        'Round_g': 'NonSymPos_s',
        'AFile_g': 'A.fix',
        'ResultFile_g': 'Result.fix',
        'RoundReg_g': "YES"
    }
    cosim = olo_fix_round.cosim.cosim
    # Different rounding modes
    for Round in ['NonSymPos_s', 'Trunc_s']:
        named_config(tb, default_generics  | {'Round_g': Round},
                    pre_config=cosim)
    # Test exactly matching format
    named_config(tb, default_generics  | {'Round_g': 'Trunc_s', 'ResultFmt_g': '(1,8,4)'},
                pre_config=cosim)
    # Different register settings
    for RoundReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'RoundReg_g': RoundReg}, pre_config=cosim)

    fix_saturate_tb = 'olo_fix_saturate_tb'
    tb = olo_tb.test_bench(fix_saturate_tb)
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(1,4,8)',
        'Saturate_g': 'Sat_s',
        'AFile_g': 'A.fix',
        'ResultFile_g': 'Result.fix',
        'SatReg_g': "YES"
    }
    cosim = olo_fix_saturate.cosim.cosim
    # Different daturation modes
    for Sat in ['Sat_s', 'None_s']:
        named_config(tb, default_generics  | {'Saturate_g': Sat},
                    pre_config=cosim)
    # Test sign removal
    named_config(tb, default_generics  | {'AFmt_g': '(1,8,8)', 'ResultFmt_g': '(0,4,8)'},
                pre_config=cosim)
    # Test sign adding
    named_config(tb, default_generics  | {'AFmt_g': '(0,8,8)', 'ResultFmt_g': '(1,4,8)'},
                pre_config=cosim)
    # Test upsizing
    named_config(tb, default_generics  | {'AFmt_g': '(0,8,8)', 'ResultFmt_g': '(0,9,12)'},
                pre_config=cosim)
    # Different register settings
    for SatReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'SatReg_g': SatReg}, pre_config=cosim)