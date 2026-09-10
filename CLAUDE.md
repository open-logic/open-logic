# CLAUDE.md

Guidance for AI coding agents working in this repository.

_Open Logic_ is a VHDL library of FPGA building blocks (areas: `base`, `axi`, `intf`, `fix`), usable from both
VHDL and Verilog. Sources live in `src/<area>/vhdl`, testbenches in `test/<area>/<entity>`, documentation in
`doc/<area>`.

## Conventions

**Read [doc/Conventions.md](./doc/Conventions.md) before writing or modifying any code.** It is the authoritative
source for naming (entities, ports, generics `_g`, constants `_c`, variables `_v`, types `_t`), file structure,
comment banners and coding style. Additional references:

- [Contributing.md](./Contributing.md) - contribution workflow, branch naming, PR rules.
- [doc/HowTo.md](./doc/HowTo.md) - detailed instructions for all tooling described below.
- [doc/fix/olo_fix_principles.md](./doc/fix/olo_fix_principles.md) - concepts behind the `olo_fix` area.
- `.claude/skills/olo-fix-new-entity/` - step-by-step skill for adding a new `olo_fix` entity.

Every new entity needs: production code, a self-checking VUnit testbench, documentation in `doc/<area>` and a link
from [doc/EntityList.md](./doc/EntityList.md).

## VHDL Code (`*.vhd`)

- Do limit the entity descriptions in file-headers to 1-2 sentences. Detailed descriptions are provided
  in the documentation that's linked from the header.

## Fixed-Point Code (`olo_fix`)

**All arithmetic in `olo_fix` components must be done through `olo_fix` entities or `en_cl_fix_pkg` functions -
never with plain `ieee.numeric_std` `signed`/`unsigned` arithmetic.**

- Prefer instantiating existing entities (`olo_fix_add`, `olo_fix_sub`, `olo_fix_mult`, `olo_fix_madd`,
  `olo_fix_resize`, `olo_fix_round`, `olo_fix_saturate`, `olo_fix_limit`, ...) over writing custom RTL.
- In VHDL-only code paths, `cl_fix_*` functions from `work.en_cl_fix_pkg` (`cl_fix_add`, `cl_fix_mult`,
  `cl_fix_resize`, `cl_fix_add_fmt`, `cl_fix_width`, ...) are the alternative. Both are fully supported.
- Formats, rounding and saturation are passed as strings on generics (e.g. `"(1,8,23)"`, `"Trunc_s"`, `"Sat_s"`)
  so that entities remain instantiable from Verilog. Convert with `cl_fix_format_from_string()` /
  `to_string()` inside the architecture.
- `numeric_std` conversions are acceptable only for non-arithmetic purposes, e.g. `to_integer(unsigned(Addr))`
  for table/RAM addressing.

Rationale: doing the math in `olo_fix`/`en_cl_fix` keeps the VHDL bit-true against the Python model in
`src/fix/python/olo_fix`, and keeps rounding/saturation behaviour consistent across the library.

Each `olo_fix` entity has a bit-true Python model in `src/fix/python/olo_fix/` with unit tests in
`src/fix/python/tests/`, and a cosim script in `test/fix/<entity>/cosim.py`. Keep the VHDL and the Python model in
sync; the testbenches compare against the model.

## Running Python Unit Tests

The `olo_fix` Python models are tested with pytest. From the repository root:

```shell
python3 -m pytest src/fix/python/tests/                  # all model tests
python3 -m pytest src/fix/python/tests/test_olo_fix_sin.py -v   # a single model
```

CI additionally reports coverage; **100% statement coverage of the Python models is required**:

```shell
python3 -m pytest src/fix/python/tests/ --cov=src/fix/python/olo_fix --cov-report=term-missing
```

Note: `--cov` occasionally fails to collect locally (scipy reload interaction). If that happens, run plain
`pytest` and check coverage in CI.

## Running Simulations

Simulations are VUnit based. Prerequisites: `pip3 install vunit_hdl` plus a simulator on the `PATH`
(GHDL by default, Questasim for coverage). Run from the `sim` directory:

```shell
python3 run.py                 # all tests, GHDL (default)
python3 run.py --nvc           # NVC
python3 run.py --modelsim      # Modelsim/Questasim
python3 run.py -p 16           # 16 threads, much faster
python3 run.py "*olo_fix_sin*" # filter by test-name pattern
python3 run.py <testcase> --gui  # open waveforms (GTKWave for GHDL/NVC)
```

New testbenches must be registered in `sim/test_configs/olo_<area>.py`. For `olo_fix` entities also add an entry
in `tools/inference_test/yaml/fix.yml`.

Code coverage (Questasim only):

```shell
python3 run.py --modelsim --coverage
python3 ./AnalyzeCoverage.py
```

## Running the Linter

VHDL is linted with [VSG](https://github.com/jeremiah-c-leary/vhdl-style-guide). The **exact** version matters:

```shell
pip3 install vsg==3.27
```

Both production code and testbenches must lint clean (no errors, no warnings) - CI enforces this.

```shell
python3 lint/script/script.py            # all files
python3 lint/script/script.py --debug    # file by file, stop at first error
```

Single file:

```shell
vsg -c lint/config/vsg_config.yml -f <path-to-file>
# VUnit verification components (test/tb) use an additional overlay:
vsg -c lint/config/vsg_config.yml lint/config/vsg_config_overlay_vc.yml -f <path-to-file>
```

VSCode tasks _Run VSG Lint_, _Run VSG Lint - All Files_ and _Run VSG Lint - VC_ are preconfigured in
`.vscode/tasks.json`.

Markdown is linted too (`.markdownlint.json`, max line length 120):

```shell
npx markdownlint-cli2 --config .markdownlint.json "**/*.md"
```

## Before Declaring a Task Complete

1. Simulations pass (`sim/run.py`).
2. VSG lint clean for production code and testbenches.
3. Python unit tests pass with 100% statement coverage (for `olo_fix` changes).
4. Documentation added/updated and linked from [doc/EntityList.md](./doc/EntityList.md).

## Style Notes

- Never use em-dashes in code, comments or documentation.
- Use UTF-8 characters only.
- VSG rejects identifiers with three or more consecutive uppercase letters (`SigIqFile_c`, not `SigIQFile_c`).
- Section comment banners are 99 characters wide in total, so dashes must be shortened inside indented blocks
  (e.g. 4 spaces + 95 dashes inside a `generate`).
