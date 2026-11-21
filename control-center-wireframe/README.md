# Control Center UI — Claude handoff package

This package contains a low-fidelity, grayscale wireframe based on the supplied Control Center screenshot and the generated visual concept.

## Start here

1. Open `01-control-center-wireframe.svg` to inspect the wireframe. It is a vector file with editable shapes and text; import it into Figma to use as a starting point.
2. Open `wireframe-preview.png` for a quick visual preview.
3. Give Claude `claude-build-prompt.md`, `component-spec.json`, and the two files in `assets/` as the implementation brief and visual references.

## Included files

- `01-control-center-wireframe.svg` — editable 1536 × 1024 desktop wireframe.
- `wireframe-preview.png` — PNG preview of the wireframe.
- `claude-build-prompt.md` — copy-ready prompt for Claude / Claude Code.
- `component-spec.json` — component inventory, content, example values, and implementation notes.
- `assets/original-reference.png` — the original user-provided screenshot.
- `assets/generated-visual-reference.png` — the generated dark glassmorphism concept.
- `build_wireframe.py` — script used to generate the SVG.

## Important notes

- This is a **wireframe handoff**, not a production-ready app or a native `.fig` file.
- The SVG uses vector shapes and text, so most elements can be edited after importing it into Figma.
- The connected-device rows in the right-side table are sample placeholders from the visual concept. The small device table inside the main panel is intentionally empty, matching the supplied screenshot's initial state.
- Treat the sample network values as example UI content, not as live network data.
- The layout is desktop-first. Ask Claude to preserve the overall hierarchy while making it responsive for smaller screens.
