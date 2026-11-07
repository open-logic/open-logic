# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

"""
Export the formulas of an ODF document into PNG images used by the documentation.

The source document contains a table with one row per image. The left column holds the file name
of the PNG to write, the right column the formula (a LibreOffice Math object). Adding a formula
therefore only requires adding a row to the table - no change of this script.

The formulas of the function approximation documentation are maintained in
doc/fix/approx/Formulas.odt, any other document following the same structure works the same way.

Usage (from the repository root):
    python3 doc/tools/ExportFormulas.py -d doc/fix/approx/Formulas.odt
    python3 doc/tools/ExportFormulas.py -d doc/fix/approx/Formulas.odt --list
    python3 doc/tools/ExportFormulas.py -d doc/fix/approx/Formulas.odt olo_fix_sqrt_formula.png
    python3 doc/tools/ExportFormulas.py -d Formulas.odt -o doc/pics

By default the PNGs are written next to the document, this can be changed through --outdir.

Requires libreoffice, poppler-utils (pdftoppm) and ImageMagick (convert) on the PATH.
"""

import argparse
import html
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
import xml.etree.ElementTree as ElementTree

# Resolution the formulas are rendered at. Chosen so that the glyph size matches the images that
# were originally exported from LibreOffice by hand.
DPI = 209

# White margin added around the formula (horizontal, vertical)
BORDER = (17, 20)

# ODF namespaces required to navigate the document content
NS = {
    "table": "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
    "draw": "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0",
    "xlink": "http://www.w3.org/1999/xlink",
}

MATH_ML = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block"><semantics>'
           '<annotation encoding="StarMath 5.0">{formula}</annotation></semantics></math>\n')


def read_formulas(document: str) -> dict:
    """
    Read the image name and the StarMath source of all formulas of an ODF document

    All tables of the document are scanned. Rows that do not contain an image name in the first
    and a formula object in the second column (e.g. the header row) are skipped.

    :param document: Path of the document
    :return: Dict of StarMath strings by image name, in the order they appear in the document
    """
    formulas = {}

    with zipfile.ZipFile(document) as odt:
        content = ElementTree.fromstring(odt.read("content.xml"))

        for row in content.iter(f"{{{NS['table']}}}table-row"):
            cells = row.findall(f"{{{NS['table']}}}table-cell")

            if len(cells) < 2:
                continue

            # The name may be split over multiple text nodes (e.g. by spell-checking marks)
            name = "".join(cells[0].itertext()).strip()
            obj = cells[1].find(f".//{{{NS['draw']}}}object")

            if not name or obj is None:
                continue

            # The formula objects are stored as sub-documents, referenced relative to the ODF root
            path = obj.get(f"{{{NS['xlink']}}}href").lstrip("./")
            source = odt.read(f"{path}/content.xml").decode("utf-8")
            match = re.search(r'<annotation[^>]*>(.*?)</annotation>', source, re.DOTALL)

            if match is None:
                raise ValueError(f"formula of '{name}' does not contain a StarMath annotation")
            if name in formulas:
                raise ValueError(f"'{name}' is present more than once in the document")

            formulas[name] = html.unescape(match.group(1))

    return formulas


def render(formula: str, png: str) -> None:
    """
    Render one StarMath formula into a PNG

    LibreOffice cannot export Math documents as images, hence the formula is printed into a PDF
    (which contains it at its original size, framed by a box) and the box content is cut out.

    :param formula: StarMath source of the formula
    :param png: Path of the PNG to write
    """
    # numpy/PIL are only required for the export, not for the models - import them lazily
    import numpy as np
    from PIL import Image

    work = tempfile.mkdtemp()

    try:
        source = os.path.join(work, "formula.mml")
        with open(source, "w", encoding="utf-8") as f:
            f.write(MATH_ML.format(formula=html.escape(formula)))

        subprocess.run(["soffice", "--headless", "--convert-to", "pdf", source, "--outdir", work],
                       check=True, capture_output=True)
        subprocess.run(["pdftoppm", "-r", str(DPI), "-png", "-singlefile",
                        os.path.join(work, "formula.pdf"), os.path.join(work, "page")], check=True)

        # Math prints title, formula and formula text into framed boxes. The box borders are the
        # only lines spanning the full width/height, hence they are easy to locate.
        page = np.array(Image.open(os.path.join(work, "page.png")).convert("L")) < 200
        rows = [i for i, v in enumerate(page.sum(axis=1)) if v > 0.5*page.shape[1]]
        top, bottom = rows[2] + 3, rows[3] - 3
        band = page[top:bottom, :]
        cols = [i for i, v in enumerate(band.sum(axis=0)) if v > 0.5*band.shape[0]]
        left, right = cols[0] + 3, cols[-1] - 3

        subprocess.run(["convert", os.path.join(work, "page.png"),
                        "-crop", f"{right - left}x{bottom - top}+{left}+{top}", "+repage",
                        "-fuzz", "2%", "-trim", "+repage",
                        "-bordercolor", "white", "-border", f"{BORDER[0]}x{BORDER[1]}",
                        png], check=True)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("images", nargs="*", help="Images to export (default: all)")
    parser.add_argument("-d", "--document", required=True,
                        help="Source document (ODF) containing the table of formulas")
    parser.add_argument("-o", "--outdir", default=None,
                        help="Directory to write the images to (default: next to the document)")
    parser.add_argument("--list", action="store_true",
                        help="List the formulas of the document without exporting anything")
    args = parser.parse_args()

    document = args.document
    outdir = args.outdir if args.outdir else os.path.dirname(os.path.abspath(document))

    if not os.path.isfile(document):
        parser.error(f"source document '{document}' does not exist")

    formulas = read_formulas(document)

    if not formulas:
        parser.error(f"{document} does not contain any formula table - see --help for the "
                     f"structure expected")

    if args.list:
        for name, formula in formulas.items():
            print(f"{name}: {formula}")
        return

    for image in args.images:
        if image not in formulas:
            parser.error(f"unknown image '{image}' - known images: {', '.join(formulas)}")

    os.makedirs(outdir, exist_ok=True)

    for image in args.images if args.images else formulas:
        render(formulas[image], os.path.join(outdir, image))
        print(f"Exported {os.path.join(outdir, image)}")


if __name__ == "__main__":
    main()
