# 023-test-viewer — info

Tests for `022-viewer.lua`:
- each test canvas in `assets/test-canvases/`, against its `.expected`
  file line by line: version, size, voices, every cell with its mark and
  age, the changed cells, and the line a refused canvas names;
- the same canvases read by hand: a blanked cell's mark, a two-byte
  character, ages, characters never changed, the refusal's text;
- the kitten and dog canvases made again by the change finder, blit and
  marks, byte for byte;
- a screen too small, colour order, nothing changed against itself, a
  canvas of another width or height, a change of marks alone, and
  overlapping mark lines.

    luajit src/023-test-viewer.lua [--dir ROOT]
