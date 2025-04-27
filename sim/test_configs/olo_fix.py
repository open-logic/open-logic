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

def add_configs(olo_tb):
    """
    Add all fix testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """

    ### VC ###
    tb = olo_tb.test_bench('olo_fix_vc_tb')
    for S in ['0', '1']:
        for F in ['0', '61']: #Ensure numbeers > double precision (53 bits)
            named_config(tb, {'Fmt_g': f'({S},15,{F})'}, 
                            pre_config=olo_fix_vc.cosim.cosim)

    ### olo_fix_abs ###
    tb = olo_tb.test_bench('olo_fix_abs_tb')
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(0,8,4)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
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

    ### olo_fix_neg ###
    tb = olo_tb.test_bench('olo_fix_neg_tb')
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(0,8,4)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
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
        
    ### olo_fix_resize ###
    tb = olo_tb.test_bench('olo_fix_resize_tb')
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(0,4,4)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
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

    ### olo_fix_round ###
    tb = olo_tb.test_bench('olo_fix_round_tb')
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(1,9,4)',
        'Round_g': 'NonSymPos_s',
        'RoundReg_g': "YES"
    }
    cosim = olo_fix_round.cosim.cosim
    # Different rounding modes
    for Round in ['NonSymPos_s', 'Trunc_s']:
        #For truncation, no additional bit is needed
        override_generics = {'Round_g': Round}
        if Round == 'Trunc_s': 
            override_generics['ResultFmt_g'] = '(1,8,4)'
        named_config(tb, default_generics  | override_generics,
                    pre_config=cosim)
    # Different register settings
    for RoundReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'RoundReg_g': RoundReg}, pre_config=cosim)

    ### olo_fix_saturate ###
    tb = olo_tb.test_bench('olo_fix_saturate_tb')
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'ResultFmt_g': '(1,4,8)',
        'Saturate_g': 'Sat_s',
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
    # Different register settings
    for SatReg in ['NO', 'AUTO']:
        named_config(tb, default_generics | {'SatReg_g': SatReg}, pre_config=cosim)

    ### olo_fix_add / sub / mult / addsub ###
    fix_addsubb_tbs = {'olo_fix_add_tb' : olo_fix_add.cosim.cosim, 
                       'olo_fix_sub_tb' : olo_fix_sub.cosim.cosim,
                       'olo_fix_mult_tb' : olo_fix_mult.cosim.cosim,
                       'olo_fix_addsub_tb' : olo_fix_addsub.cosim.cosim}
    for tb_name, cosim in fix_addsubb_tbs.items():
        tb = olo_tb.test_bench(tb_name)
        #Test formats and round/sat modes
        default_generics = {
            'AFmt_g': '(1,8,4)',
            'BFmt_g': '(1,5,7)',
            'ResultFmt_g': '(0,6,3)',
            'Round_g': 'NonSymPos_s',
            'Saturate_g': 'Sat_s',
            'OpRegs_g': 1,
            'RoundReg_g': "YES",
            'SatReg_g': "YES"
        }
        # Different rounding
        for Round in ['NonSymPos_s', 'Trunc_s']:
            for Sat in ['Sat_s', 'None_s']:
                named_config(tb, default_generics  | {'Round_g': Round, 'Saturate_g': Sat},
                                pre_config=cosim)
        #Different formats
        for AFmt in ['(0,8,4)', '(1,3,12)']:
            for BFmt in ['(0,5,7)', '(1,3,15)']:
                named_config(tb, default_generics  | {'AFmt_g': AFmt, 'BFmt_g': BFmt},
                                pre_config=cosim)
        # Different register settings
        for OpRegs in [0, 4]:
            named_config(tb, default_generics | {'OpRegs_g': OpRegs}, pre_config=cosim)
        for RoundReg in ['NO', 'AUTO']:
            named_config(tb, default_generics | {'RoundReg_g': RoundReg}, pre_config=cosim)
        for SatReg in ['NO', 'AUTO']:
            named_config(tb, default_generics | {'SatReg_g': SatReg}, pre_config=cosim)

    ### olo_fix_compare ###
    tb = olo_tb.test_bench('olo_fix_compare_tb')
    #Test formats and round/sat modes
    default_generics = {
        'AFmt_g': '(1,8,8)',
        'BFmt_g': '(1,4,3)',
        'Comparison_g': '=',
        'OpRegs_g': 1
    }
    cosim = olo_fix_compare.cosim.cosim
    # Comparison modes
    for Comparison in ['=', '!=', '<', '<=', '>', '>=']:
        named_config(tb, default_generics  | {'Comparison_g': Comparison},
                        pre_config=cosim)
    # Different register settings
    for OpRegs in [0, 4]:
        named_config(tb, default_generics | {'OpRegs_g': OpRegs}, pre_config=cosim)

    ### olo_fix_from_real ###
    tb = olo_tb.test_bench('olo_fix_from_real_tb')
    #Test formats and round/sat modes
    for Format in ['(1,4,4)', '(0,4,4)', '(0,4,0)', '(0,0,4)']:
        for Value in ['1.0', '1.33', '0.5', '-0.25', '0.125']:
            named_config(tb, {'ResultFmt_g': Format, 'Value_g': Value})

    ### olo_fix_to_real ###
    tb = olo_tb.test_bench('olo_fix_to_real_tb')
    #Test formats and round/sat modes
    for Format in ['(1,4,4)', '(0,4,4)', '(0,4,0)', '(0,0,4)']:
        for Value in ['1.0', '1.33', '0.5', '-0.25', '0.125']:
            named_config(tb, {'AFmt_g': Format, 'Value_g': Value})

    ### olo_fix_pkg ###
    # Does not need configuration

    ### olo_fix_limit ###
    tb = olo_tb.test_bench('olo_fix_limit_tb')
    #Test formats and round/sat modes
    default_generics = {
        'InFmt_g': '(1,8,8)',
        'LimLoFmt_g': '(1,8,8)',
        'LimHiFmt_g': '(0,8,8)',
        'ResultFmt_g': '(1,8,8)',
        'Round_g': 'NonSymPos_s',
        'Saturate_g': 'Sat_s',
        'UseFixedLimits_g': False,
        'FixedLimLo_g': '0.0',
        'FixedLimHi_g': '0.0'
    }
    cosim = olo_fix_limit.cosim.cosim
    # default
    named_config(tb, default_generics, pre_config=cosim, short_name='default')
    # Fixed limits
    fix_generics = default_generics.copy()
    fix_generics.pop('LimLoFmt_g', None)
    fix_generics.pop('LimHiFmt_g', None)
    named_config(tb, fix_generics | {'UseFixedLimits_g': 'True', 'FixedLimLo_g': '-3.25', 'FixedLimHi_g': '5.0'},
                 pre_config=cosim, short_name='fixed_limits')
    # Different formats
    for LimLoFmt in ['(1,8,4)', '(1,3,12)']:
        for LimHiFmt in ['(0,8,4)', '(1,3,12)']:
            named_config(tb, default_generics  | {'LimLoFmt_g': LimLoFmt, 'LimHiFmt_g': LimHiFmt},
                         pre_config=cosim, short_name=f'diff-formats-Lo={LimLoFmt}-Hi={LimHiFmt}')
    # Different register settings
    for RoundReg in ['NO', 'AUTO']:
        for SatReg in ['NO', 'AUTO']:
            named_config(tb, default_generics | {'RoundReg_g': RoundReg, 'SatReg_g': SatReg},
                         pre_config=cosim, short_name=f'diff-regs-RoundReg={RoundReg}-SatReg={SatReg}')
