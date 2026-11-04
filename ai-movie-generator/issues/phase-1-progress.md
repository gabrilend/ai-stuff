# Phase 1 Progress — the image call and the run

## Goals

The foundation every other phase stands on: talking to ComfyUI, and the
shape of a run.

- the project's run script: ${DIR}, RAM tiers, reads `input/` first, writes
  the goodbye receipt to `output/` last;
- the ComfyUI client: start-check, upload, queue, wait, fetch;
- workflow templates with placeholders (text-to-image, image-to-image,
  text-to-image with control), chosen by a dispatch table;
- the picture request and the render log;
- the contact sheet viewer (reads PNGs, writes one tiled PNG).

Ends with: the phase-1 demo renders a dozen station stills from a list,
shows them as a contact sheet, and prints seconds-per-picture and
pictures-per-minute read from the render log.

## Completed Issues
(None yet. Counts: /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/ai-movie-generator -m)
