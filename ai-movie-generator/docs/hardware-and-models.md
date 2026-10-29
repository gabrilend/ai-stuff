# Hardware and models — what the machine can actually do

This document records what is installed, so the design stays inside it. To
see the current numbers rather than trust these, run (once phase 1 exists)
the project's check script, which asks ComfyUI and ollama what they hold.

## The graphics card

One NVIDIA GTX 1080 Ti with 11 GB of video memory. It is a 2017 card: no
tensor cores, so half-precision gives memory savings but little speed. A
512×512 Stable Diffusion 1.5 image at ~20 sampling steps takes on the order
of seconds, not milliseconds — the exact figure is measured by the image
call's receipt (see datapath-image-call.md), not written here.

**The card is shared.** ComfyUI holds its model in video memory while it
runs; ollama loads its language model into the same memory when asked.
SD 1.5 plus a 9-billion-parameter language model do not comfortably fit
together. The pipeline therefore runs in two halves:

1. the writers' room (language model) finishes the whole shot list,
   then asks ollama to unload (`keep_alive: 0`);
2. the painter and animator (ComfyUI) run.

This ordering is a design rule, not a tuning choice: a stage that needs the
language model during rendering must say so in its issue file.

## The image server: ComfyUI at /mnt/kaun/stable-diffusion

- Started by `/mnt/kaun/stable-diffusion/run`; listens on 127.0.0.1:8188.
  Its settings are in `/mnt/kaun/stable-diffusion/config`.
- Accepts **workflow graphs in API format** (a JSON object of numbered
  nodes), never a bare prompt. See that project's `workflows/README.md`.
- Its log is at `/mnt/kaun/stable-diffusion/tmp/shared-memory/comfyui.log`.

### Models installed there

| kind | name | use here |
|---|---|---|
| base model (diffusers folder) | Dreamshaper-8 (SD 1.5) | every keyframe |
| controlnet | depth, openpose, canny, lineart, softedge, tile, … (SD 1.5) | holding a pose or composition between shots; tile for upscaling |
| ip-adapter | standard, plus, plus-face | holding a character's face across shots — **needs a custom node pack that is not installed** (custom_nodes/ is empty) |
| clip vision | SD 1.5 image encoder | used by ip-adapter |
| embeddings | EasyNegative, ghostsong-off-brand-* (fantasy races) | negative prompt; character species |
| upscaler | SwinIR 4× | final frames |

There is no motion model (no AnimateDiff, no video diffusion). Motion is
therefore made *outside* the diffusion model — camera moves and image-to-image
drift — see datapath-shot-to-clip.md.

## The language server: ollama

`ollama` on the default port 11434. Installed models relevant here:

| model | size | role |
|---|---|---|
| qwen3.5:9b | 6.6 GB | writer, director, creator (default) |
| gemma3:12b-it-qat | 8.9 GB | alternative writer, if quality calls for it |
| llama3.2 | 2.0 GB | fast drafts while iterating on prompts |
| llava | 4.5 GB | looks at a rendered keyframe and says what is in it (checking a shot matches its description) |
| nomic-embed-text:v1.5 | 274 MB | turns phrases into vectors: the semantic space the arc is navigated through |

## The particle painter: gif-generator

`/mnt/mtwo/programming/ai-stuff/gif-generator`. Reads a *score* (a Lua file
of light strokes on a timeline) and writes an animated gif of glowing
particles. Deterministic, CPU-only, no flicker. Used for shots that diffusion
renders poorly: visions, energy, abstract sound, transitions, title cards.
Its front door for a person is `./say`; this project calls its renderer
directly with a score file it writes.

## Command-line tools

ffmpeg (decode, encode, camera moves, concatenation), sox (audio
measurement), luajit, curl. **No speech engine is installed.**
`/usr/bin/piper` is the GTK gaming-mouse configuration tool (Void package
piper-0.8), not the Piper text-to-speech engine; only espeak-ng's runtime
library is present. Which engine to install is open question 8.
