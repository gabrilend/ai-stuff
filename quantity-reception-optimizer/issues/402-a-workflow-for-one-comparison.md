# 402 — A workflow for one comparison

## Current behavior

Nothing exists. Needs `303` for the scene and `401` for the cells. The server
is `192.168.0.88:8188`; the checkpoint is not yet chosen (open question 2b in
`docs/008`).

## Intended behavior

**From an analogy record and its cell layout, build the ComfyUI graph that
draws it — one object per cell.**

The graph:

- load the checkpoint
- encode the **setting** (the background the model chose: "a bakery floor")
  as the prompt for the whole frame
- for each cell, encode that cell's line ("one white paper sack of flour") and
  restrict it to the cell's rectangle with ComfyUI's built-in
  `ConditioningSetArea` node; the partial cell's line says "part of a sack of
  flour, cut off by the edge of the frame"
- join the setting and every cell into one conditioning with
  `ConditioningCombine` nodes (they take two inputs each, so N cells is a chain
  of N joins)
- empty latent at the frame size, sample, decode, save

All of these nodes are in ComfyUI's core and were confirmed present on the
server (`/object_info`, 2026-10-04).

**If area prompts do not hold the count** — the model draws two sacks in one
cell or none in another — the alternative is to draw one object once and paste
copies into the cells (`ImageCompositeMasked`, also core). That count is exact
by construction, but the result looks pasted. Which one is used is decided by
the phase 4 demo's count column, and the decision and its reason are written
into `docs/005`. If both are kept, they are two modes behind one setting and
both are tested.

**It is built with the graph writer the kanji project already has**
(`kanji-learning-image-generator/src/028-the-shape-of-a-graph.lua`), loaded the
way `world-edit-to-execute/src/assets/comfy.lua` loads it. That writer knows
every socket of every node in slot order and refuses to wire one it does not
know. Its catalogue gains the area and combine nodes. Read its `.info.md` and
the kanji project's issue 301 first.

Both formats are written: the API format, which the host posts, and the editor
format, for opening a bad case on the ComfyUI canvas by hand.

Checkpoint, frame size, steps, sampler and negative prompt are settings.

## Suggested implementation steps

1. `src/` — the workflow module: analogy record, cell list and settings in;
   graph in both formats out.
2. A check against the server: every node and input the graph uses exists in
   its `/object_info`. The neighbour project has the same check (`comfy.lua
   check`); reuse it.
3. Tests without ComfyUI: both formats describe the same connections; there are
   exactly as many area nodes as cells; each area matches its cell.

## Related

`docs/005-datapath-the-picture.md` · `docs/008-open-questions.md` (2b) · needs
`303`, `401` · blocks `403`, `404`
