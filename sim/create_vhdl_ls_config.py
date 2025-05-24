# --------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bruendler
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Any

import rtoml

if TYPE_CHECKING:
    from vunit.ui import VUnit

def create_configuration(  # noqa: C901
    output_path: Path,
    vunit_proj: VUnit | None = None,
    files: list[tuple[Path, str]] | None = None
    ) -> None:
    """
    Create a configuration file (``vhdl_ls.toml``) for the rust_hdl VHDL Language Server
    (https://github.com/VHDL-LS/rust_hdl).

    Can be used with modules and an "empty" VUnit project, or with a complete VUnit
    project with all user files added.
    Files can also be added manually with the ``files`` argument.

    Execution of this function takes roughly 12 ms for a large project (62 modules and a
    VUnit project).

    Arguments:
        output_path: vhdl_ls.toml file will be placed in this folder.
        modules: All files from these modules will be added.
        vunit_proj: All files in this VUnit project will be added.
            This includes the files from VUnit itself, and any user files.

            .. warning::
                Using a VUnit project with user files and location/check preprocessing enabled is
                dangerous, since it introduces the risk of editing a generated file.
        files: All files listed here will be added.
            Can be used to add additional files outside of the modules or the VUnit project.
            The list shall contain tuples: ``(Path, "library name")``.
    """
    toml_data: dict[str, dict[str, Any]] = {"libraries": {}}

    def add_file(file_path: Path, library_name: str) -> None:
        """
        Note that 'file_path' may contain wildcards.
        """
        if library_name not in toml_data["libraries"]:
            toml_data["libraries"][library_name] = {"files": []}

            if library_name in ["vunit_lib", "osvvm", "unisim", "xil_defaultlib"]:
                toml_data["libraries"][library_name]["is_third_party"] = True

        toml_data["libraries"][library_name]["files"].append(str(file_path.resolve()))

    if vunit_proj is not None:
        for source_file in vunit_proj.get_compile_order():
            add_file(file_path=Path(source_file.name), library_name=source_file.library.name)

    if files is not None:
        for file_path, library_name in files:
            add_file(file_path=file_path, library_name=library_name)

    # Ignore unused work library statement
    if "lint" not in toml_data:
        toml_data["lint"] = {}
    toml_data["lint"]["unnecessary_work_library"] = False

    rtoml.dump(obj=toml_data, file=output_path / "vhdl_ls.toml", pretty=True)
