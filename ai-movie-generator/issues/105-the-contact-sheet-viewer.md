# 105 — the contact sheet viewer

phase 1, the image call and the run

**Depends on:** 104

## Current behavior

No way to see many pictures at once.

## Intended behavior

A viewer, separate from all generators: given a folder of PNGs (and optionally the shot list), tile them into one `contact-sheet.png` with each picture's id and time under it. Uses ffmpeg's tile filter; reads only.

## Suggested implementation steps

1. Collect, sort by shot order or name.
2. Label and tile with ffmpeg.
3. Test on three generated solid-colour pictures.

## Related documents

- docs/datapath-reel-assembly.md
