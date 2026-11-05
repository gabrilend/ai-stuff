# 024-test-canvas-files — info

Tests for the canvas files the blitter writes (issue 203), on a throwaway
project:
- a replay of the phase-1 series (018): `history/000001` to `000008` with no
  gaps and nothing else, no half-written file left, and `current` byte for
  byte the last version;
- each history file read by the viewer reader (022): its own version, the
  viewers' headers (project and commit, mode, voices) and its marks;
- the history as the blitter's memory: nothing held but the current
  version, a file never rewritten, and a base refused when its file is gone;
- a restart: the folder emptied, numbering carried on from `current`, a base
  from before refused, a new base taken, the receipt counting this run's
  versions only, and the commit `0000000` outside git;
- a reboot (the RAM tiers emptied): numbering carried on from
  `output/blitter-version`.

    luajit src/024-test-canvas-files.lua [--dir ROOT]
