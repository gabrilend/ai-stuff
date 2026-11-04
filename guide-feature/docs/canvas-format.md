# Canvas format

One text form for the canvas, used in all three places it travels:

- kuvalu → voices, as the body of the living rmail message `the-canvas`;
- voice → kuvalu, as the body of the living rmail message `canvas`;
- kuvalu → viewers, as files and over HTTP (`docs/canvas-protocol.md`).

Each direction uses a different set of header lines, but the rows and the
marks are written the same way everywhere, and one reader and one writer
handle all of them.

## Layout

    <header lines, one "name: value" per line, in the order listed>
    <one blank line>
    <exactly H rows>
    marks:
    <zero or more mark lines>
    cuts:                          (kuvalu → voices only)
    <zero or more cut lines>

The number of rows is known from the `size` header, so an empty row (a row
of spaces, or an empty line) is never confused with the end of the rows.

### Rows

Exactly `H` lines. Each holds at most `W` characters (UTF-8 code points).
A row shorter than `W` is the same as that row padded with spaces, so a
writer may drop trailing spaces. A line longer than `W`, or a row count other
than `H`, is an error: the reader refuses it and names the row.

A **word** is a run of characters containing no space. Its position is its
row (1 to `H`) and the column of its first character (1 to `W`).
Punctuation is part of the word next to it.

### Marks

Written by kuvalu only. A voice's canvas has an empty marks section, and
any marks it sends are ignored and counted.

    mark: ROW COLUMN LENGTH VOICE VERSION KIND

| Field | Type | Meaning |
|---|---|---|
| ROW, COLUMN | whole numbers | where the marked cells begin |
| LENGTH | whole number | how many cells, on that row only |
| VOICE | name | who changed it: `fg-sora-1`, `-2`, `-3`, or `kuvalu` (the distiller) |
| VERSION | whole number | the canvas version at which it changed |
| KIND | `word`, `sentence` or `orphan` | `word`: these cells were written or blanked. `sentence`: the rest of the sentence holding a changed word. `orphan`: leftover letters of a word cut under the `fade-fragments` collision rule (`docs/datapath-blit.md`), to be drawn dim; VOICE is the voice that cut it |

A **sentence** is the words, in reading order (left to right, top to
bottom), between sentence-ending punctuation (`.` `!` `?` at the end of a
word) or an entirely empty row.

A cell has at most one mark: the newest. When a newer change covers older
marks, the older ones are gone. Marks older than a setting's number of
versions are dropped, so a canvas that stops changing ends with no marks.

### Cuts

Only in the canvas kuvalu sends to the voices, and only when the
tell-the-voice setting is on (`docs/datapath-blit.md`, "Collision rules").
One line per word cut since that voice's previous turn landed:

    cut: VOICE VERSION ROW COLUMN TEXT

VOICE is the voice that did the cutting, VERSION the version it happened
at, ROW and COLUMN where the cut word stood, and TEXT the whole word as it
was. Every voice receives the same body, and each voice's turn reads only
its own lines, so one living message still serves all three.

## Headers, kuvalu → voices (`the-canvas`)

    canvas: 18
    size: 60x20
    mode: newest
    project: guide-feature 9f2c1e0
    endpoint: voice-small http://192.168.1.100:<port>
    written: 2026-10-21T22:10:05Z

| Field | Type | Meaning |
|---|---|---|
| `canvas` | whole number | the version |
| `size` | `WxH` | the canvas size in characters |
| `mode` | `newest` or `distill` | the merge mode in use (voices may be told how their edits are used) |
| `project` | name and commit | the project being worked on, and the commit each voice's clone should be at (`docs/datapath-looking-into-the-project.md`) |
| `endpoint` | name and address | the model server this voice uses for its next turn, chosen on kuvalu (`docs/endpoints.md`) |
| `written` | UTC time `YYYY-MM-DDThh:mm:ssZ` | when kuvalu wrote this version |

## Headers, voice → kuvalu (`canvas`)

    voice: fg-sora-2
    turn: 41
    base: 18
    size: 60x20
    written: 2026-10-21T22:10:48Z

| Field | Type | Meaning |
|---|---|---|
| `voice` | name | who wrote it. Must match the rmail sender, or the canvas is refused. |
| `turn` | whole number | the voice's own turn counter. A jump of more than one means rmail delivered only the newest of several (counted). Going backwards is an error. |
| `base` | whole number | the canvas version this turn started from. kuvalu looks it up in its history to see what this voice changed (`docs/datapath-blit.md`). |
| `size` | `WxH` | must equal the size of the base version |
| `written` | UTC time | when the turn finished |

## Headers for viewers

The same as kuvalu → voices, plus `voices:` (the voice names, in the order
viewers should give them colours). See `docs/canvas-protocol.md`.

## Rules for every header block

Headers appear in the order listed, once each. Missing, repeated, unknown or
out-of-order headers make the whole canvas an error. The reader names the
line and refuses it. It never guesses a value.
