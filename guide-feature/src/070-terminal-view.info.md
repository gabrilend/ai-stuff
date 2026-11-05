# 070-terminal-view — info

The terminal view (issue 801): the canvas in any terminal on kuvalu, in
st's plain style, with plain escape codes and no curses.

    scripts/terminal-view [ROOT] [OPTIONS]     Ctrl-C or TERM stops it cleanly
    luajit src/070-terminal-view.lua --dir ROOT [--once] [--replay FOLDER]
        [--size CxR] [--for SECONDS] [--plain]

- A thin border (box-drawing lines) at the canvas's size, the canvas inside
  it at the top left. Cells with no mark are in the default colour.
- A marked cell is in its voice's colour (`colours`, by the voice's place in
  the `voices:` header; `kuvalu-colour` for the distiller's marks, 601).
  How bright is a table from age to step: `word-steps` for word marks,
  `sentence-steps` for sentence and orphan marks; the first step is for age
  0, older marks take the last. `bright` is the colour's bright code, bold;
  `normal` the colour; `dim` the colour, faint.
- It looks at `tmp/shared-memory/canvas/current` every `check-every`
  seconds and draws again when the text changed or the terminal was
  resized; each drawing clears the screen first. No animation.
- A terminal smaller than the canvas and its border shows only
  "the canvas is 16x3 (18x5 with its border); this terminal is 17x5".
- The terminal's size comes from the terminal (TIOCGWINSZ), else COLUMNS and
  LINES, else 80x24 with a log line; `--size` sets it.
- Stops on a file named `stop` in `tmp/shared-memory/terminal-view/`
  (`scripts/terminal-view` drops it), at the end of a `--replay`, after
  `--once`, or after `--for`.

Receipt (`output/goodbye-terminal-view`): `versions-read`,
`versions-drawn`, `too-small`, `unreadable`, `seconds-run`. Each version drawn
is logged as `drew version N at SECONDS` (the wall clock, to the
millisecond), which the phase 8 demo (804) sets beside when it was written.

| Name | Meaning |
|---|---|
| `draw(view, { columns, rows, settings, plain })` | the screen's text, and whether the canvas was drawn |
| `style(view, mark, settings)` | a mark's escape-code parameters, or nil |
| `too_small(view, columns, rows)` | the error, or nil |
| `read_settings(root)` | `input/terminal-view`, its lists checked |
| `run(opts)` | the program: `root`, `once`, `replay`, `columns`, `rows`, `seconds`, `plain`, `write`, `clock` |
| `terminal_size()` | columns, rows, or nil |

Tests: `071-test-terminal-view.lua`; references in `assets/test-terminal/`.
