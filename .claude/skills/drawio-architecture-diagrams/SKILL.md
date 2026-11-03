---
name: drawio-architecture-diagrams
description: Create draw.io architecture/block diagrams (drawio.png with embedded source) for Open Logic documentation. Use when a doc needs a block diagram of an entity.
---

## Instructions

Create an architecture diagram as `<name>.drawio.png` in `doc/<area>/approx/` (or the area's figure folder).
The PNG **embeds the draw.io source**, so no separate `.drawio` file is kept. Embed it in the markdown
under the "Architecture" heading.

## Step 1: Study existing diagrams first

- Look at the diagrams of comparable entities and mimic them (style, colors, flow direction, label sizes):
  - `doc/fix/approx/olo_fix_inv.drawio.png`, `olo_fix_sqrt.drawio.png`
  - `doc/fix/approx/olo_fix_lin_approx_arch.drawio.png` (symbols for bus split/merge, add, multiply)
- View the PNG with the Read tool (it is rendered as an image).
- Extract the embedded XML to reuse exact styles (see "Reading embedded XML").

## Step 2: Choose the elements (symbols, not just boxes)

The user wants **schematic symbols for simple operations**. Blue boxes are NOT acceptable for arithmetic or
wiring. Use:

- Addition: circle with `+`
- Subtraction: circle with `-` (mark input polarity with small `+`/`-` labels where the order matters)
- Multiplication: circle with `x`
- Logic gates: **European (IEC) notation**, a plain rectangle (not the American shapes) with the function
  written inside. Draw it as a white rectangle with black stroke, e.g. 40x40 for two inputs:
  - AND: `&`
  - OR: `>=1`
  - XOR: `=1`
  - NOT: `1` with a small circle (negation bubble) on the output
  - NAND / NOR: the AND / OR rectangle with a negation bubble on the output
  - Inputs enter on the left, the output leaves on the right
- Multiplexer: trapezoid with the select input on the side and the input numbers (`0`, `1`) inside
- Constants: plain text label (e.g. `-1`, `I-1`) with an arrow into the circle
- Concatenation / bus merge and split: **thick vertical bar** (line with `strokeWidth=4`, no arrowheads)
  with arrows ending at / starting from the bar
- Operations that are wiring only (e.g. dropping the leading one): express them as an operation on the
  value (e.g. add `-1`), not as a box named "Drop MSB"
- Fork of a signal: line starting with a dot (`startArrow=oval;startFill=1`)

Boxes are only for real building blocks:

- Grey (`fillColor=#f5f5f5;strokeColor=#666666;fontColor=#333333`): Open Logic entities, named exactly
  like the entity (`olo_base_dyn_sft`, `olo_base_latency_comp`, `olo_fix_resize`, ...)
- Blue (`fillColor=#dae8fc;strokeColor=#6c8ebf`): custom logic that has no symbol (e.g. "Leading Zeros")
- Yellow (`fillColor=#fff2cc;strokeColor=#d6b656`): tables / memories

## Step 3: Make labels consistent with the code and doc

- Use the real names from the code: generics/ports (`In_Data`, `Out_Result`) at the diagram edges.
- Label signals with the math symbols used in the doc (e.g. `N`, `m`, `k`, `log2(1+m)`).
- Never invent a constant name that differs from the VHDL. Check what a name means in the code first
  (e.g. `IntBits_c` is the width of the result integer part, which is NOT the input integer bits `I`).
  If the user's wording differs from the code, use the code-correct label and tell the user.
- Color-code symbols that appear in a formula figure (red/blue text), if the doc has one.
- Show the algorithmic data flow only. Leave out pipeline registers unless the user asks for them.

## Step 4: Layout

- Main data path left to right on one horizontal line (y = 300 in the generator below).
- Side paths (shift count, sign, integer part, constants) below or above the main line.
- Input label on the left, output label on the right, both as plain text (fontSize 12).
- Orthogonal lines only. Use waypoints for elbows.
- Keep label font size 8, entity boxes 100-160 wide and 40-60 high, circles 30x30.
- Avoid crossings. Where an unavoidable fork exists, use a dot.

## Step 5: Generate the XML with a script

- Write a small Python generator (scratchpad, not in the repo) with helpers:
  - `box(id, x, y, w, h, html_value, style)`
  - `lbl(id, x, y, w, h, html_value, align, fontSize)` (text only, `strokeColor=none;fillColor=none`)
  - `circle(id, x, y, text)` (`ellipse;aspect=fixed;fillColor=#ffffff;strokeColor=#000000;fontSize=14`)
  - `gate(id, x, y, text)` (`rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#000000`, text
    `&`, `>=1`, `=1`, ... in European notation)
  - `edge(id, points, start_dot=False)` with `sourcePoint`, `targetPoint` and an `Array as="points"` for elbows
  - `bar(id, x, y1, y2)` (edge, `endArrow=none;strokeWidth=4`)
- Escape XML in values (`quoteattr`). HTML in values is allowed (`<sup>`, `<font color=...>`).
- Wrap in `<mxfile host="Electron" scale="2" border="0"><diagram ...><mxGraphModel ...><root>` with the two
  base cells `id="0"` and `id="1" parent="0"`.

## Step 6: Export to drawio.png with embedded source

- The draw.io CLI is `drawio` (snap). The snap **cannot read files in the scratchpad or /tmp**.
  Copy the `.drawio` file temporarily next to the target (inside the repo / home), export, then delete it.
- Command (run in the target folder):

```shell
drawio -x -f png --embed-diagram -s 2 -b 10 -o <name>.drawio.png tmp_<name>.drawio
rm tmp_<name>.drawio
```

- Verify that the PNG contains the source (Pillow): `Image.open(png).info` has an `mxGraphModel` or
  `mxfile` key.
- GTK warnings ("atk-bridge") are harmless.

## Step 7: Check the result

- Open the PNG with the Read tool and check: overlaps, arrow directions, label positions, polarity labels.
- Iterate on the generator, not on the PNG.
- Add the image to the markdown: `![Block Diagram](./approx/<name>.drawio.png)` with a one-sentence intro.
- Lint the markdown (`npx markdownlint-cli2 --config .markdownlint.json <file>`).

## Reading embedded XML

- Pillow: `Image.open(png).info["mxGraphModel"]` (or `["mxfile"]`), then `urllib.parse.unquote`.
- If the `<diagram>` content is not XML, it is base64 + raw deflate: `zlib.decompress(b64decode(d), -15)`
  followed by `unquote`.

## Style rules

- Never use em-dashes in labels or docs.
- UTF-8 only.
- Do not claim in the doc that label colors match a formula figure unless such a figure exists.
- Mention in the hand-over message any label that differs from the user's wording and why.
