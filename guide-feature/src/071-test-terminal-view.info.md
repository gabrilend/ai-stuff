# 071-test-terminal-view — info

Tests the terminal view (issue 801).

    luajit src/071-test-terminal-view.lua --dir ROOT [--write-references]

- **The shared test canvases** (`assets/test-canvases/`) drawn for 80x24
  and compared byte for byte with `assets/test-terminal/`.
- **What the references hold**, on 04-aging: the clear and the border; a
  word mark bright at age 0 and plain at age 2; sentence and orphan marks
  dim; kuvalu's colour; unmarked cells with no code; `--plain`; a fifth
  voice taking the colours round again; a mark reaching the row's end
  closed before the border.
- **Too small**: the error naming both sizes; exactly the size fits. The
  settings' refusals.
- **The program**: `--replay` of a folder with one unreadable file, and its
  receipt; a terminal too small for every version; the live view through
  `scripts/terminal-view`, drawing `canvas/current`, not again while it is
  unchanged, again when it is replaced by rename; the stop file; the
  receipt; `--once`.
