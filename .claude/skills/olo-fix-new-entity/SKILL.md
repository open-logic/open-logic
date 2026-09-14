## Instructions

Implement a new Open Logic olo_fix entity. Use context from the open repository (check a few items in:

- /doc/fix
- /src/fix (python and VHDL)
- /test/fix (Testbench and cosim script)

Before you start, always ask the following questions:

1. What's the name of the entity
2. Whats the functionality
3. What architectures are needed (does it implement serveral or only one)
4. What generics shall it have
5. What ports shall it have

Use existing open logic entities where required (e.g. olo_fix_add, olo_fix_mult and olo_fix_resize).

Create the production code first. Then create the bit-true python model plus unit tests for it. Reach 100% statement
coverage. Then create teh testbenc hand cosim.py. Also add entries in sim/test_configs/fix.py and
tools/inference_test/yaml/fix.yml. Also create the documentation for the new entity and link to it from EntityList.md.

Ask questions where unclear before you start.

Before you deem the task to be completed, always do:

- Run simulations (/sim/run.py - VUNIT)
- Run VSG linter on production code and testbenches, fix all issues
- Ensure 100% statement coverage for python unit tests

## Rules

- Never use em-dashes
- For all output, always use UTF-8 characters only

## Learnings from earlier entities implemented

### VSG Linter Rules

#### Section Comment Width Inside Generate Blocks

Comments inside `generate` blocks are indented by 4 spaces. VSG enforces that the total
line length stays at 99 chars, so the dashes must be shorter:

```vhdl
-- Top-level section (99 dashes):
---------------------------------------------------------------------------------------------------

-- Inside generate block (4 spaces + 95 dashes = 99 chars total):
    -----------------------------------------------------------------------------------------------
```

Run VSG early and often -- `vsg --rules block_comment` catches this class of issue.

#### Constant Naming (constant_004)

VSG rejects names with 3 or more consecutive uppercase letters (regex `(?!.*[A-Z]{3})`).

- Bad:  `SigIQFile_c`, `ResyncMixIQFile_c`
- Good: `SigIqFile_c`, `ResyncMixIqFile_c`

This applies to signal and variable names too.

### Python Model Pattern

When the new entity is a subset or specialisation of an existing one, wrap it instead of
reimplementing:

```python
from .olo_fix_cplx_mult import olo_fix_cplx_mult

class olo_fix_mix_c2r:
    def __init__(self, in_fmt, mix_fmt, out_fmt, round=..., saturate=...):
        self._inner = olo_fix_cplx_mult(in_fmt, mix_fmt, out_fmt, round, saturate, mode="MIX")

    def next(self, sig_i, sig_q, mix_i, mix_q):
        out_i, _ = self._inner.next(sig_i, sig_q, mix_i, mix_q)
        return out_i
```

Use `_` for unused return values to avoid IDE warnings about unused variables.

### TDM Architecture Sizing

The shift-register arrays `Valid_I` and `Valid_Q` only need to be as long as the highest
index actually used. For a design that reads index `MultRegs_g + 1`:

```vhdl
constant Stages_c : natural := MultRegs_g + 2;  -- indices 0 .. MultRegs_g+1
signal Valid_I : std_logic_vector(0 to Stages_c - 1);
```

Do not copy `Stages_c` blindly from reference entities -- recalculate from the highest
used index.

### Cosim: TDM Resync Test Data

Pattern for the IqResync tests (TDM mode only):

1. Generate N normal I/Q pairs (2N TDM samples).
2. Append a single I sample with `Last=1` (the resync marker).
3. Append N more I/Q pairs (2N TDM samples).
4. Total input: `4N + 1` TDM samples; total output: `2N` real samples (the lone I sample
   produces no output -- it resets the phase tracker).

Write two separate output files: `Resync_ResultReal.fix` (the expected real outputs) and
`Resync_LastOut.fix` for the output-side Last propagation if needed.

### Checklist for a New Entity

1. `src/fix/vhdl/olo_fix_<name>.vhd` -- production VHDL
2. `src/fix/python/olo_fix/olo_fix_<name>.py` -- bit-true model
3. `src/fix/python/olo_fix/__init__.py` -- add `from .olo_fix_<name> import *`
4. `src/fix/python/tests/test_olo_fix_<name>.py` -- unit tests (100% coverage)
5. `test/fix/olo_fix_<name>/cosim.py` -- generates .fix stimulus/reference files
6. `test/fix/olo_fix_<name>/olo_fix_<name>_tb.vhd` -- VUnit testbench
7. `sim/test_configs/olo_fix.py` -- add `tb` block with `named_config` calls
8. `tools/inference_test/yaml/fix.yml` -- add entity with in_reduce/out_reduce
9. `doc/fix/olo_fix_<name>.md` -- documentation
10. `doc/EntityList.md` -- add link in the correct alphabetical position

### Verification Flow

```bash
# Python unit test coverage
cd src/fix/python
python3 -m pytest tests/test_olo_fix_<name>.py -v --tb=short
python3 -m pytest tests/test_olo_fix_<name>.py --cov=olo_fix --cov-report=term-missing

# VSG linter
vsg -f src/fix/vhdl/olo_fix_<name>.vhd --rules_file tools/vsg/vsg_rules.yaml
vsg -f test/fix/olo_fix_<name>/olo_fix_<name>_tb.vhd --rules_file tools/vsg/vsg_rules.yaml

# Simulation
python3 sim/run.py -p 16 "*<name>*"
```

All three must pass before the entity is considered done.
