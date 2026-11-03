---
name: olo-wavedrom
description: Generate wavedrom waveforms (JSON + PNG) for Open Logic documentation. Use when a doc needs a timing diagram.
---

## Instructions

Create a wavedrom waveform for the documentation. Store **both** files next to each other:

- `<name>.json` (source)
- `<name>.png` (embedded in the markdown)

Location: `doc/<area>/entities/` for entity examples (see `doc/general/*.json` for generic ones).

## Workflow

1. Write the JSON (strict JSON, see rules below).
2. Render to SVG with the Python package `wavedrom` (installed in the venv).
3. Rasterize the SVG with **headless Chrome** (see commands below).
4. Look at the PNG (Read tool) and fix problems.
5. Embed in the markdown: `![Name](./entities/<name>.png)`.
6. Run markdownlint on the changed doc.

## Rendering

Render to an HTML page (SVG inline). Use the scratchpad for temporary files.

```python
import wavedrom
svg = wavedrom.render(open("x.json").read()).tostring()
open("p.html", "w").write('<html><body style="margin:0;background:white">' + svg + '</body></html>')
# viewBox of the svg gives the window size
```

```shell
google-chrome --headless --disable-gpu --no-sandbox --hide-scrollbars --force-device-scale-factor=<S> \
  --default-background-color=FFFFFFFF --window-size=<W>,<H> --screenshot=out.png file://$PWD/p.html
```

## Image Size

- Do **not** set a fixed width. The size is defined by the **height per signal**.
- Target: **30 px per signal** (as in `doc/base/fifo/olo_base_fifo_packet_basic.png`: 12 signals, 360 px).
- This is the native wavedrom size, so use `<S>` = **1** (no scaling). Width follows from the number of columns.
- Spacer lines (`{}`) count as signals.
- Do not use scale 2, the text and the figure then look much bigger than the other figures in the docs.
- Check with `identify <name>.png`: height / number of signals should be 30.

## Pitfalls

- **Do not use ImageMagick** (`convert`) for SVG to PNG. It ignores the CSS and produces garbage.
- `python3 -m wavedrom` does not work. Use the API (`wavedrom.render`).
- `wavedrom.render()` returns an object: use `.tostring()` (or `.saveas()`).
- Chrome needs an HTML wrapper with inline SVG and `--window-size` equal to the SVG `viewBox`, otherwise the image
  is cropped.
- Keep the JSON strict (double quotes, no trailing commas). Python wavedrom is stricter than the web editor.

## Wave String Rules

- All wave strings of a diagram must have the **same number of characters**. Count them!
- `P` = clock with arrows, `.` = repeat previous, `0`/`1` = levels, `x` = undefined/don't care.
- `=` = data box (text from `data` array in order), `x` = hatched.
- Colored data boxes: `5` = blue, `3` = yellow, `4` = orange (consistent with `doc/general/tdm_last.png`).
  Use one color per channel/source.
- `|` = break (e.g. latency). It occupies **one column in every signal**. Put it on an idle column,
  never in the middle of a data sample (it swallows the sample).
- `{}` as signal = empty spacer line (e.g. between inputs and outputs).
- A gap in `Valid` = a column where Valid is `0` and data is `x`.
- Keep data labels short (`Ch0`, `Ch1`), otherwise they overlap the box borders.

## Layout Recommendation

- Idle column, samples, idle column, break, idle column, output samples, idle column.
- Signal order: Clk, inputs, spacer, outputs.
- Explain colors and special features (gap, break, restart) in one short paragraph above the figure.

## Reference

- `doc/fix/entities/olo_fix_dds_example.json` / `.png`
