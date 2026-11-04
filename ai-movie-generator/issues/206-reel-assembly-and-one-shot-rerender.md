# 206 — reel assembly and one shot rerender

phase 2, shots into motion

**Depends on:** 203, 205

## Current behavior

Clips cannot become a film.

## Intended behavior

`run assemble`: checks every shot has a clip of the right length, concatenates in order, lays the film's sound under it, writes `reel.mp4` and a contact sheet, keeps the run in `output/<run>/`. `run shot <id>`: re-renders one shot and re-assembles — the inner loop of iteration. Clips whose shot line has not changed are reused (a fingerprint of the shot's resolved request beside each clip).

## Suggested implementation steps

1. Checks.
2. ffmpeg concat + sound.
3. Fingerprints and reuse.
4. Test: change one shot, only that clip is re-rendered.

## Related documents

- docs/datapath-reel-assembly.md
