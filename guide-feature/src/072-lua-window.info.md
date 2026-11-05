# 072-lua-window — info

The Lua window (issue 802): the recommended viewer, the canvas drawn as a
picture, each new version's changed words written in over what was there.
Everything but the window is built; until kuvalu has a window library it
draws headless and saves screenshots (see the issue's "Needs the owner's
machine").

    scripts/lua-window [ROOT] [OPTIONS]   Ctrl-C or TERM stops it; then its
                                          screenshots are filed
    luajit src/072-lua-window.lua --dir ROOT [--replay FOLDER]
        [--screenshot SECONDS]... [--key SECONDS NAME]... [--for SECONDS]
        [--fast] [--file-screenshots [MADE-BY]]

- **Letters**: the monorepo's own 8x8 pictures (`libs/bitmap-font.lua`,
  copied from every-software-image-able), each `letter-scale` times bigger.
  The eleven printable characters that font lacks (dollar, percent,
  ampersand, at, backslash, caret, backtick, braces, bar, tilde) are drawn here (`EXTRA_PICTURES`); anything else is the font's hollow box.
- **Colour behind a cell**: its voice's colour (`voice-colours`, by the
  voice's place in the `voices:` header, round again past the last;
  `kuvalu-colour` for the distiller) laid over `background` at a strength
  from `word-strengths` or `sentence-strengths` by the mark's age (the
  last for every older age). Orphan marks count as sentence marks.
- **Writing over**: a run is the changed cells of one word (changed cells on
  a row with only unchanged letters between them). Each run is written left
  to right over `write-seconds`; the k-th cell of L turns at k/L of it and
  shows the old character, in its old colour, until then. All runs at once.
  Frames are drawn `frames-per-second` while writing; none while nothing
  changes. A version arriving before the last is written in full cuts it
  short: the last is shown in full and the new one written over it.
- **Screenshots** (`--screenshot SECONDS`, the `s` key) save the frame at
  that moment to `tmp/shared-memory/lua-window/screenshots/NN-at-SSS.SSs-
  version-V.png`, beside a `.txt` of the same frame: the characters, then
  what is behind each cell (`.` nothing, `1 2 3` a voice's word mark, `a b c`
  its sentence mark, `K k` kuvalu's, `~` still being written over). The PNG
  is written uncompressed, needing no library. `--file-screenshots` moves
  them into `development-history/NNN-lua-window-...` with an `.info.md`.
- **Keys** (`--key SECONDS NAME`, or a window's own): `q` or `escape` stops,
  `space` pauses and resumes a replay, `s` screenshots; others are logged.
- `--fast` runs on a pretend clock: the same frames, no waiting.
- Stops on a file named `stop` in `tmp/shared-memory/lua-window/`, at the
  end of a `--replay` (after its last scheduled screenshot or key), or
  after `--for`.

Receipt (`output/goodbye-lua-window`): `versions-received`,
`versions-drawn`, `cut-short`, `frames-drawn`, `screenshots`,
`keys-pressed`, `unreadable`, `seconds-run`.

| Name | Meaning |
|---|---|
| `read_settings(root)` | `input/lua-window`, its colours and lists checked |
| `background(view, mark, s)`, `strength(mark, s)`, `voice_colour(view, mark, s)`, `blend(under, over, t)` | the colour behind a cell |
| `animation(view, previous, started, seconds)` | one version's writing-over: `flips[row][column]`, `ends`, `runs`, `changes` |
| `frame(writing, t, s)` | the cells on screen at time t, and `done` |
| `glyph(character)` | a letter's eight row bytes, and whether the font has it |
| `raster(frame, s)` | the frame as pixels |
| `png(picture)` | a PNG file's bytes |
| `text_grid(frame, writing)` | the frame as text |
| `run(opts)` | the program: `root`, `replay`, `screenshots`, `keys`, `seconds`, `clock`, `backend` |
| `BACKENDS` | where frames go; only `headless` so far |
| `file_screenshots(root, made_by)` | files waiting screenshots into `development-history/` |
| `real_clock()`, `pretend_clock()` | the clocks |

Tests: `073-test-lua-window.lua`.
