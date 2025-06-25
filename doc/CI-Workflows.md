<img src="../doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# CI Workflows

## Overview

The table below gives an overview about which workflows are triggered by which events and where they run.

| Workflow                                          | Runs on:<br />PR to _develop_<br />(contribution) | Runs on:<br />PR to _main_<br />(pre release) | Run on:<br />Push to _main_<br />(post release) | Runs monthly | Runs daily | Infrastructure:<br />GitHub Runner | Infrastructure:<br />AWS Runner |
| ------------------------------------------------- | :-----------------------------------------------: | :-------------------------------------------: | :---------------------------------------------: | :----------: | :--------: | :--------------------------------: | :-----------------------------: |
| [HDL-Check](#hdl-check)                           |                         x                         |                       x                       |                        x                        |      x       |            |                 x                  |                                 |
| [Doc-Check](#doc-check)                           |                         x                         |                       x                       |                        x                        |      x       |            |                 x                  |                                 |
| [analyze-issues](#analyze-issues)                 |                                                   |                                               |                                                 |              |     x      |                 x                  |                                 |
| [Coverage Simulation](#coverage-simulation)       |                                                   |                       x                       |                        x                        |      x       |            |                                    |                x                |
| [FuseSoC Test](#fusesoc-test)                     |                                                   |                       x                       |                        x                        |      x       |            |                                    |                x                |
| [Reference Design Build](#reference-design-build) |                                                   |                       x                       |                        x                        |      x       |            |                                    |                x                |
| [Synthesis Test](#synthesis-test)                 |                                                   |                       x                       |                        x                        |      x       |            |                                    |                x                |

**Note:** Workflow runs of PRs from forks require approval by the maintainer. This setup was chosen to avoid needless
ost regarding AWS infrastructure and for security reasons (to avoid malicious code being executed in CI pipelines
of _Open Logic_).

## Tool Versions

The following tool versions are installed on the AWS runner and hence checked regularly:

- Questa Intel Starter FPGA Edition 2022.4
- Vivado v2024.2
- Quartus Prime Lite 24.1
- Gowin EDA V1.9.11.02
- Microchip Libero 2024.2
- Efinity 2024.1
- GHDL 3.0.0
- NVC 1.13.3

## HDL-Check

This workflow does the following things:

- HDL Simulations without coverage using free Simulators (NVC, GHDL)
  - No coverage check
- HDL Linting (VSG)
- Check if all entities are covered by the YAML files for _Synthesis Test_
  - But not actually running synthesis (synthesis requires an AWS runner)

This workflow is specifically written to run on a free GitHub runner, so it can run on every contribution PR at no cost.

## Doc-Check

This workflow does the following things:

- Markdown Linting

This workflow is specifically written to run on a free GitHub runner, so it can run on every contribution PR at no cost.

## analyze-issues

This workflow does the following things:

- Check if there are open GitHub issues related to certain entities and update their issues badge

This workflow is specifically written to run on a free GitHub runner, so it can run on every contribution PR at no cost.

This workflow runs daily to ensure information about bugs and potential bugs is up to date.

## Coverage Simulation

This workflow does the following things:

- HDL simulations with coverage using Questa
- For PRs to main:
  - Raise an error if coverage for any file is < 95%
- On main:
  - Update coverage information badges for every entity

Tools for this workflow requires a NIC locked license, therefore it runs on an AWS runner.

## FuseSoC Test

This workflow does the following things:

- Build the FuseSoC reference designs

Tools for this workflow requires large tool installations, therefore it runs on an AWS runner.

## Synthesis Test

This workflow does the following things:

- Run synthesis for every block in open-logic

Tools for this workflow requires large tool installations, therefore it runs on an AWS runner.

## Reference Design Build

This workflow does the following things:

- Build all reference designs contained in the tutorials

Tools for this workflow requires large tool installations and NIC locked licenses, therefore it runs on an AWS runner.
