# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Oliver Bründler
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------

"""
Export the formula images of the function approximation documentation.

The formulas are maintained in Formulas.odt (LibreOffice Math objects). This script renders one of
them into a PNG, so the images can be regenerated after editing the document.

Usage (from this directory):
    python3 ExportFormulas.py --list
    python3 ExportFormulas.py --all
    python3 ExportFormulas.py olo_fix_sqrt_formula.png

Requires libreoffice, poppler-utils (pdftoppm) and ImageMagick (convert) on the PATH.
"""

import argparse
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

# Resolution the formulas are rendered at. Chosen so that the glyph size matches the images that
# were originally exported from LibreOffice by hand.
DPI = 209

# White margin added around the formula (horizontal, vertical)
BORDER = (17, 20)

# Name of the PNG per formula of Formulas.odt, in the order the formulas appear in the document
IMAGES = [
    "olo_fix_inv_formula.png",
    "olo_fix_inv_error.png",
    "olo_fix_sqrt_formula.png",
    "olo_fix_sqrt_error.png",
]

DOCUMENT = "Formulas.odt"

MATH_ML = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<math xmlns="http://www.w3.org/1998/Math/MathML" display="block"><semantics>'
           '<annotation encoding="StarMath 5.0">{formula}</annotation></semantics></math>\n')


def read_formulas(document: str) -> list:
    """
    Read the StarMath source of all formulas of an ODF document

    :param document: Path of the document
    :return: List of StarMath strings, in the order the formulas appear in the document
    """
    with zipfile.ZipFile(document) as odt:
        # The objects are referenced by the document body in the order they appear in it
        body = odt.read("content.xml").decode("utf-8")
        names = re.findall(r'xlink:href="\./(Object \d+)"', body)
        formulas = []

        for name in names:
            content = odt.read(f"{name}/content.xml").decode("utf-8")
            match = re.search(r'<annotation[^>]*>(.*?)</annotation>', content, re.DOTALL)
            formulas.append(html.unescape(match.group(1)))

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
    parser.add_argument("--list", action="store_true",
                        help="List the formulas of the document without exporting anything")
    parser.add_argument("--all", action="store_true", help="Export all images")
    args = parser.parse_args()

    directory = os.path.dirname(os.path.abspath(__file__))
    formulas = read_formulas(os.path.join(directory, DOCUMENT))

    if len(formulas) != len(IMAGES):
        parser.error(f"{DOCUMENT} contains {len(formulas)} formulas but {len(IMAGES)} images are "
                     f"configured - update IMAGES")

    if args.list:
        for image, formula in zip(IMAGES, formulas):
            print(f"{image}: {formula}")
        return

    images = args.images if args.images and not args.all else IMAGES

    for image in images:
        if image not in IMAGES:
            parser.error(f"unknown image '{image}' - known images: {', '.join(IMAGES)}")
        render(formulas[IMAGES.index(image)], os.path.join(directory, image))
        print(f"Exported {image}")


if __name__ == "__main__":
    main()
