# Canvas protocol

What every viewer depends on. A viewer can be built in any language (Lua, a
shell script, Kotlin, Swift, JavaScript) from this page and
`docs/canvas-format.md` alone, without reading guide-feature's source.

## The text

The canvas format (`docs/canvas-format.md`) with the viewer headers:

    canvas: 18
    size: 60x20
    mode: newest
    project: guide-feature 9f2c1e0
    written: 2026-10-21T22:10:05Z
    voices: fg-sora-1 fg-sora-2 fg-sora-3

    <20 rows of at most 60 characters>
    marks:
    mark: 3 12 7 fg-sora-2 18 word
    mark: 3 20 31 fg-sora-2 18 sentence
    mark: 9 1 5 fg-sora-1 16 word

To skim, a viewer shows each mark's cells differently from unmarked cells,
for example in the voice's colour, with older marks (lower VERSION compared
with the canvas version) fainter. The canvas itself is always the truth. A
viewer never moves, re-wraps or edits the characters.

## How to get it

The same text, byte for byte, in two ways.

### On kuvalu: files

In the project's RAM folder, `tmp/shared-memory/canvas/`:

| File | Contents |
|---|---|
| `current` | the newest version, replaced as a whole by rename, so a reader never sees half a canvas |
| `history/NNNNNN` | every version this run, six-digit zero-padded, never rewritten. The blitter also reads these to find each voice's base. |

### Over HTTP

The canvas server on kuvalu (port set in `input/canvas-server`):

| Request | Answer |
|---|---|
| `GET /canvas` | the newest version, `text/plain; charset=utf-8` |
| `GET /canvas?after=N` | waits up to 60 seconds for a version above N, then answers with it, or `204 No Content` if none came, and the viewer asks again |
| `GET /canvas/N` | version N from history, or `404` |
| `GET /` | the HTML viewer page (`issues/803-the-html-page.md`) |

Anything else is `404`.

From outside the home network, this server is the only thing that can be
reached: the router forwards one port to it, the "narrow cause-way"
(`docs/network.md`). It is read-only and answers nothing beyond the routes
above.

## Rules a viewer must follow

- Read the headers and the blank line, then exactly `H` rows, then the marks.
  A malformed canvas is an error to show, not to work around.
- Never change the characters. Show what the canvas says.
- A viewer may keep the previous version to animate the change (draw the
  newly marked cells arriving over the old ones), but the newest version is
  always the truth.
- A screen smaller than the canvas shows an error naming both sizes. It
  does not squeeze or crop the canvas.
