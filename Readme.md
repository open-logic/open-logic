<img src="./doc/Logo.png" alt="Logo" width="400">

![example workflow](https://github.com/obruendl/open-logic/actions/workflows/simulation.yml/badge.svg) 
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/version.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/date.json?cacheSeconds=0)

# Open Logic - A VHDL Standard Library

*Open Logic* aims to be what *stdlib* is for C/C++ projects. 

*Open Logic* implements commonly used components in a reusable way and provide them under a permissive open source license (LGPL modified for FPGA usage, see [License.txt](./License.txt)), so the code can be used in commercial projects. 

Browse the [Entity List](./doc/EntityList.md) to see what is available.

## Structure

*Open Logic* is split into the following areas. You might use all of them or only the ones you need.

* [base](./doc/EntityList#base) - basic logic to be used for device internal logic
* [axi](./doc/EntityList#axi)  - any components related to AXI4/AXI4-Lite/AXI4-Stream interfaces
  * requires: *base*
* [interface](./doc/EntityList#interface)  - any logic related to device external interfaces 
  * requires: *base*

## Project Philosophy

*Open Logic* is not the first open source VHDL library - so you might ask yourself what makes it different ans why you should use this one. The project follows the philosophy below - the decision whether this matches what you are looking for is yours.

### Trustable Code

Open source HDL projects exist but they are by far not as popular as open source software projects. One main problem is that there is little trust in open source HDL code. In some cases code quality is not great and in general RTL designers probably are less used to relying on code from others.

*Open Logic* aims to provide code that can be trusted - and to provide measures that would indicate if this is the case for every individual piece of code in the library. This is implemented by the following measures:

1. Every entity comes with a testbench.
2. The project comes with a CI workflow, which regularly runs all simulations. The batch on the very top of this page indicates if there is a problem. As long as it is green - you know that all testbenches pass.
3. Indicators for open issues on every entity. In the documentation of every piece of code, you can find a batch that informs you about the number of issues related to this piece of code, if there are *potential bugs* (orange color) or even *confirmed bugs* (red color).
   ![issues](https://img.shields.io/badge/issues-0-green) ![issues](https://img.shields.io/badge/issues-2-orange) ![issues](https://img.shields.io/badge/issues-2-red)
4. Indicator for code coverage on every entity. In the documentation of every piece of code, you can find a batch stating the code coverage. Additionally a batch in this readme states for which git-commit coverage was last analyzed..
   ![issues](https://img.shields.io/badge/statement coverage-98.3%-green)

Note that a non-zero number of issues not necessarily is a bad sign - issues include things like feature requests. But probably you at least want to check the issues in detail if the color is not green.

### Ease of Use
Ease of use instead of feature-creep. Only the logic with a high probability of being used in many places shall go into the library. Each block shall only solve one core topic - whatever can be realized externally is not included to avoid needless complexity and crowded configuration options. 

You do not have to care about generics or ports you do not use. Any optional configuration options or ports come with a default value - if you do not have a specific need, you can just omit those and a common default value is used.

All blocks come with proper markdown documentation. You can easily look up if there is a component that fits your needs, how it is implemented and how you can use it.

### Pure VHDL

*Open Logic* does not rely on vendor specific code (e.g. primitives) and can be compiled to very FPGA or even ASICs. Code is written with different technologies in mind (e.g. using read-before-write or write-before-read blockrams, containing synthesis attributes for different tools) and hence works efficiently on all devices available.

Thanks to the *pure VHDL* philosophy, *Open Logic* simulates fast and is fully supported by the open-source GHDL simulator. This is crucial for an open-source project because it allows participating on the development at zero tool-cost.

## Origin of the Project

The *Open Logic* project is based on the [psi_common](https://github.com/paulscherrerinstitute/psi_common/tree/57aa85217e727b5fbddf8f000b270ab77602b03e) library provided by Paul Scherrer Institute. I would like to give credits to the authors of this library, especially Benoit Stef, who maintained the project after I left PSI.

I decided to create *Open Logic* instead of more actively working on the PSI libraries for two main reasons:

* I want to build a true community project which is not owned by one institution (and clearly labeled as such)
* I want full freedom of discard and rework whatever is needed to build a trustable library after I got the feedback that code quality of the PSI libraries became somewhat mixed. 
* I want full freedom to revise any conceptual decisions I do not (anymore) agree with.

## Next Steps

- [x] Building the infrastructure (documentation, CI pipelines, etc.) based on a small subset of the functionality
- [ ] Port functionality from *psi_common* which is trustable. Refactor where required and modify testbenches for VUnit compatibility.
- [ ] Port functionality from *psi_common* which requires significant rework.
- [ ] Port functionality from *psi_fix*
- [ ] Build reference designs and training materials

New functionality may be added at any time (also between above steps).

## How To ...

### ... Run Simulations

If you want to run simulations on your PC, you need the following prerequisites:

1. *Python 3* must be installed
2. VUnit must be installed: `pip3 install vunit-hdl`
3. Simulator must be installed and added to the *PATH* environment variable  
   1. Default choice: [GHDL](https://github.com/ghdl/ghdl/releases)
   2. Alternative (used for code-coverage analysis): Questasim. 

To run the simulations, navigate to *<root>/sim* and execute the following command:

```
python3 run.py            # For GHDL
python3 run.py --modelsim # For Modelsim/QuestaSim
```

You should now see an output indicating that all tests pass.

![simulation](./doc/general/Simulation.png)



### ... Analyze Coverage

To analyze code-coverage, the Questasim simulator must be used and coverage must be enabled. After simulations with coverage enabled are ran, the coverage can be reported nicely formated in the console by runnign the corresponding python script.

```
python3 run.py --modelsim --coverage
python3 ./AnalyzeCoverage.py 
```

You should now see a clean summary of the statement coverage:

![simulation](./doc/general/Coverage.png)





