<img src="../doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](../Readme.md)

# Open Logic - How To ...

## ... Use Open Logic in a Questasim Simulation

There is a script to compile all *Open Logic* sources into a library *olo*. To run the script, follow the steps below:

1. Open Questasim
2. In the Questasim TCL shell, execute the command `source <open-logic-root>/tools/questa/vcom_sources.tcl`

That's it. Nothing more.

* All *Open Logic* sources are configured to be compiled into the library *olo*
  ![Sources](./general/questa/vcom_sources.png)



## ... Use Open Logic in a Efinix Efinity Project

There is a script to import all *Open Logic* sources into a Efinity project.

**Note:** The script does not setup automatic constraints because Efinity does not support scoped constraints (in contrast to the AMD Vivado tools). For Efinity all constraints must be added manually.

To run the script, follow the steps below:

1. Create a project in Efinity (if it does not yet exist)
2. Close the project in Efinity. Remember where it is stored on the file-system.
3. Open a terminal window and navigate to *\<open-logic-root\>/tools/efinity*
4. Run the command `python3 ./import_sources.py --project <path-to-project-xml> --library <library-name>`
   Replace `<path-to-project-xml>` by the path to the project file (to the *project.xml* file, NOT the *project.peri.xml* )
   Replace `<library-name>` by the library to compile open-logic sources into (*olo* for VHDL, *default* for Verilog)
5. Open the project in Efinity again. You should now see all *Open Logic* sources being added
   ![Sources](./general/efinity/import_sources.png)

Two more notes:

* For the usage of *Open Logic* from Verilog, the *default* library has to be chosen because Efinity does require the top-entity to be in the *default* library and for Verilog Efinity does only allow using VHDL entities in the same library as the module instantiating them. That's why using VHDL entities in any other library (e.g. named *olo* ) is not possible.
* You can get help regarding the *import_sources.py* script by calling `python3 ./import_sources.py -h`
* The *import_sources.py* script does create a backup of the project file, so you can restore it if something goes wrong. The backup file is stored under *\<name\>.xml.backup*.

## ... Use Open Logic in a AMD Vivado Project

There is a script to import all *Open Logic* sources into a Vivado project and apply all automatic constraints. To run the script, follow the steps below:

1. Open Vivado and create a project (if not existing yet)
2. Open the TCL shell in Vivado
3. Execute the command `source <open-logic-root>/tools/vivado/import_sources.tcl`
   Replace `<open-logic-root>` by the path of your *Open Logic* working copy.

That's it. Nothing more.

* All *Open Logic* sources are configured to be compiled into the library *olo*
  ![Sources](./general/vivado/import_sources_sources.png)
* A new constraints file for importing all scoped constraints is added to the Vivado project by the script.
  
  **Note:** Scoped constraints are always imported but only work for usage from VHDL. For Verilog usage, manual constraints are required. Refer to the documentation of entities that require constraints (clock-crossings, interfaces, etc.)
  ![Constraints](./general/vivado/import_sources_constraints.png)

## ... Use Open Logic in a Intel Quartus Project

There is a script to import all *Open Logic* sources into a Quartus project.

**Note:** The script does not setup automatic constraints because Quartus does not support scoped constraints (in contrast to the AMD Vivado tools). For Quartus all constraints must be added manually.

To run the script, follow the steps below:

1. Open Quartus and create a project (if not existing yet)
2. Open the TCL shell in Quartus
   ![Sources](./general/quartus/launch_tcl_shell.png)
3. Execute the command `source <open-logic-root>/tools/quartus/import_sources.tcl`
   Replace `<open-logic-root>` by the path of your *Open Logic* working copy.

That's it. Nothing more.

* All *Open Logic* sources are configured to be compiled into the library *olo*
  ![Sources](./general/quartus/import_sources.png)

Because Quartus does not support scoped constraints, **NO** constraints are important. They have to be created manually - more information can be found in the documentation of individual *Open Logic* entities which require constraints.

## ... Use Open Logic through FuseSoC

[FuseSoC](https://github.com/olofk/fusesoc) is a package manager and build system for HDL projects. Open Logic supports fuse-soc. To use Open Logic through fusesoc, just add open logic as a library:

```
fusesoc library add open-logic https://github.com/open-logic/open-logic
```

You should now get one package listed for every area in Open Logic. You can us them independently (dependencies are modelled in FuseSoC correctly and resolved automatically). You also see the tutorials being available and buildable through FuseSoC.

```
user$ fusesoc core list

Available cores:

Core                                       Cache status  Description
================================================================================
open-logic:open-logic:axi:2.0             :      empty : AXI related modules 
open-logic:open-logic:base:2.0            : downloaded : Basic Circuitry (e.g. FIFOs, CDCs, ...) 
open-logic:open-logic:intf:2.0            : downloaded : Interfaces (e.g. I2C, synchronizer, SPI, ...) 
open-logic:tutorials:quartus_tutorial:1.0 :      empty : quartus tutorial for open-logic, targetting DE0-CV board
open-logic:tutorials:vivado_tutorial:1.0  :      empty : vivado tutorial for open-logic, targetting Zybo Z7-10 board

```

**Note:** Like for all other tool integrations, Open Logic entities are compiled into the library *olo* and can be instantiated using e.g. `i_fifo : entity olo.olo_base_fifo_sync`.

## ... Run Simulations

If you want to run simulations on your PC, you need the following prerequisites:

1. *Python 3* must be installed
2. VUnit must be installed: `pip3 install vunit_hdl`
3. Simulator must be installed and added to the *PATH* environment variable  
   1. Default choice: [GHDL](https://github.com/ghdl/ghdl/releases)
   2. Alternative (used for code-coverage analysis): Questasim. 

To run the simulations, navigate to *\<root\>/sim* and execute the following command:

```
python3 run.py            # For GHDL
python3 run.py --modelsim # For Modelsim/QuestaSim
python3 run.py --nvc      # For NVC
```

Tipp: For faster runtimes, you may want to use multiple threads to execute simulations. This can be achieved by adding the argument `-p 16` (16 is the number of threads, you may use any other number fitting your CPU).

You should now see an output indicating that all tests pass.

![simulation](./general/Simulation.png)

## ... Open a Simulation in the GUI

For debugging purposes, you may want to visualize a test-case in the GUI. 

For GHDL and NVC simulations, the GTKWave tool must be installed (it's the GUI to GHDL/NVC). For Questasim a GUI is included.

To show simulation results in the GUI, navigate to *\<root\>/sim* and execute the following command:

```
python3 run.py <testcase> --gui
```

Where test-case is the exact test-case to display, e.g. "olo_tb.olo_base_cc_bits_tb.D=19-N=20.SimpleTransfer" in above printscreen.

```
python3 run.py olo_tb.olo_base_cc_bits_tb.D=19-N=20.SimpleTransfer --gui
```

The simulator GUI will show up (the example is showing GTKWave - the GHDL/NVC GUI):

![SimGui](./general/GtkwaveGui.png)

## ... Analyze Coverage

To analyze code-coverage, the Questasim simulator must be used and coverage must be enabled. After simulations with coverage enabled are ran, the coverage can be reported nicely formated in the console by running the corresponding python script.

Below commands must be ran from the *\<root\>/sim* directory:

```
python3 run.py --modelsim --coverage
python3 ./AnalyzeCoverage.py 
```

You should now see a clean summary of the statement coverage:

![simulation](./general/Coverage.png)

## ... Update Badges

The issue badges are updated every night using a GitHub workflow.

For the code coverage badges, the situation is a bit more complicated because Questasim is required to produce coverage and Questasim is non-free and licensed to specific PCs.

In order to update coverage badges, a PC with the following prerequisites is required:

1. Questasim must be installed (including license setup)
2. A credential JSON file giving access to the google cloud storage folder below is required and the path to it must be stored in the environment variable *GCS_FILE*: <br>https://storage.googleapis.com/open-logic-badges
   The google cloud storage is maintained by [obruendl](oliver.bruendler@gmx.ch).

To update the coverage badges, simply execute the following commands in the *\<root\>/sim* directory: 

```
python3 run.py --modelsim --coverage
python3 ./AnalyzeCoverage.py --badges
```















