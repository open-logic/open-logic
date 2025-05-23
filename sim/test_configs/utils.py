# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from functools import partial

# ---------------------------------------------------------------------------------------------------
# Functionality
# ---------------------------------------------------------------------------------------------------
def named_config(tb, map : dict, pre_config = None, short_name = None):
    cfg_name = "-".join([f"{k}={v}" for k, v in map.items()])
    if short_name is not None:
        cfg_name = short_name
    if pre_config is not None:
        pre_config = partial(pre_config, generics=map)
    tb.add_config(name=cfg_name, generics = map, pre_config=pre_config)