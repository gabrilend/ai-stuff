# Issue A09: Imagine the View

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Status:** Open
**Dependencies:** A08 (see-in-3d); the ComfyUI installation at /mnt/kaun/stable-diffusion

---

## Why this exists

> the goal is to create an imaginitive imagining of the modelled viewpoint,
> using the input images (portraits of the scene) alongside the description
> (based on a tool call result that the llm generated)

see-in-3d draws what a model read a picture to be, as plain shapes from four
sides. This takes one of those viewpoints and asks Stable Diffusion to
imagine it as a picture: shaped by the scene, coloured and textured by the
original picture, and described by the scene's own words.

## Current Behavior

Built and tested without a server: every render now also writes each
view's depth map (`-depth.png`, near bright); `see-in-3d imagine` renders the
chosen view's depth at 512, builds the workflow
(`scripts/libs/see-in-3d-imagine.lua`), and with `--dry-run` writes it beside
the scene. The server calls (upload, queue, wait, fetch) are written but not
yet run: the ComfyUI installation cannot start until its `update` finishes —
started 2026-10-10 with every missing library built into the project, it was
compiling OpenBLAS when last looked at.

The installation has Dreamshaper 8 (SD 1.5, diffusers folder), a depth
ControlNet, a "shuffle" ControlNet, and IP-Adapter weights, but no custom
nodes, so the IP-Adapter cannot be used.

**First real picture, 2026-10-10, on the machine nearby** (192.168.0.88: AMD
Radeon, 32 GB, ComfyUI 0.22, SDXL checkpoints, no ControlNets, no embeddings,
no IP-Adapter). For a server like that there is a second mode, chosen
explicitly with `--mode=render`: the drawn view itself is encoded and repainted
(image-to-image, `--denoise` how far it may wander), so the layout comes from
the render and no ControlNet is needed. Before posting, the command asks the
server for its checkpoints and ControlNets and stops naming any the workflow
needs and the server lacks. `--server`, `--checkpoint`, `--steps`, `--cfg`,
`--sampler`, `--scheduler`, `--size` choose the rest. The corridor example at
1024 on Juggernaut XL, denoise 0.72: the floor kept its place and its cyan
seams became runes, the purple came back as an arched doorway at the far end,
and the right wall and the chequered floor were dropped for a blank room —
at that denoise the model keeps the layout's strong lines and repaints the rest.

**All 25 gallery examples imagined** with `see-in-3d imagine-all` (same
settings, denoise 0.7, a few shared style words after each scene's own
description), kept in each example folder as `imagined.jpg` with
`imagined.info` naming what made it — kept, not remade, because it took a
graphics card's time and another card would draw a different picture. The
gallery shows it as a third panel, and the published page was updated. The
words carried what the shapes could not: the guide's room came back as a
glass-fronted case with the ledger and key, the glass the paintbrush has no
word for.

Depth map, decided: the grey range is spread over the shapes only, the floor
clipped at both ends; spread over the floor too, a desk came out barely
brighter than the ground beneath it.

## Intended Behavior

`see-in-3d imagine SCENE.lua --view=angle [--picture=PNG] [--prompt=TEXT]
[--seed=N] [--strength=0..1]`:

1. **Shape.** The view is rendered at 512 with its **depth map** — the
   renderer's own depth buffer written as a grey picture, near bright and far
   dark, the convention depth ControlNets are trained on. It is exact, not
   estimated from a picture.
2. **Look.** The source picture (the note's picture, or `--picture`) goes to
   the shuffle ControlNet, which carries its colours and textures, not its
   layout.
3. **Meaning.** The prompt is the scene's `what` line, plus `--prompt` words.
4. A ComfyUI workflow is written as JSON from these — core nodes only:
   load Dreamshaper 8, encode prompt and negative, two ControlNets applied in
   turn, sample with a fixed seed, decode, save — sent to the local server,
   waited on, and the picture saved beside the scene as
   `SCENE-VIEW-imagined.png` with the workflow beside it.
5. No server answering is an error that names `./run`; nothing is guessed.

## Suggested Implementation Steps

1. Renderer returns depth with colour; `render` writes `-depth.png` per view.
2. JSON writer (sorted keys); workflow builder as a pure function.
3. Upload images and queue the prompt over HTTP (curl); poll history; fetch
   the result.
4. Tests without a server: depth brighter where nearer; the workflow names
   every node it wires and is the same for the same inputs. With a server:
   one imagined view of a gallery example.

## Open Questions

1. The IP-Adapter would carry the source picture's look more faithfully than
   shuffle. It needs the ComfyUI_IPAdapter_plus custom node, cloned into
   `custom_nodes/`. Wanted?
2. A small fast model to download as well (she said "we can download a small
   fast one too"): which? An SD 1.5 "LCM" or "turbo" model samples in 4–8
   steps instead of 25.
