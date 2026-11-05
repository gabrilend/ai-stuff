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

Each version is written to `history/` first, then to `current`. Both are
written under a name starting with `.` and renamed into place. When the
blitter starts, it empties the folder, so the history is this run's only.
Its numbering carries on from the previous run's last version, which it
reads from `current` and, so that it outlives a reboot, from
`output/blitter-version` on disk. A version number is never used twice. So a
viewer waiting for a version above N still gets the next one after a
restart, and a voice's base from before is refused rather than mistaken for
a new version (issue 203).

### Over HTTP

The canvas server on kuvalu (port set in `input/canvas-server`):

| Request | Answer |
|---|---|
| `GET /canvas` | the newest version, `text/plain; charset=utf-8` |
| `GET /canvas?after=N` | waits up to 60 seconds for a version above N, then answers with it, or `204 No Content` if none came, and the viewer asks again |
| `GET /canvas/N` | version N from history, or `404` |
| `GET /` | the HTML viewer page (`issues/completed/803-the-html-page.md`) |
| `GET /session?viewer=NAME` | a session for that viewer (below), or `404` |

Anything else is `404`. A method other than `GET` on these routes is `405`.
A request larger than `max-request-bytes` is `413`. One that takes longer
than `request-seconds` to arrive is `408`. A connection beyond
`max-connections` is `503`. Every answer closes its connection (no
keep-alive), so a viewer opens a new one for each request. All of these are
set in `input/canvas-server`. Built in `src/025-canvas-server.lua`
(issue 204).

### Locked, in a session

Outside the four machines the canvas is sent locked (`docs/network.md`,
issue 803). A request for it with no session there is `403`. `send-plain`
in `input/canvas-server` says who may have it plain: the four machines
(`local`), `everyone`, or `nobody`.

1. `GET /session?viewer=NAME` answers lines of `name: value`:

        session: 3f9a...   (32 hex digits)
        viewer: NAME
        kind: key          (or password)
        salt: -            (32 hex digits for a password viewer)
        rounds: -          (PBKDF2 rounds, for a password viewer)
        key: 9c1e...       (hex)

   `key` is the session's own key (32 bytes), sealed with the viewer's key.
   A viewer's key is in their address after `#` (`#NAME:KEY`, 64 hex
   digits), or made from their password with PBKDF2-HMAC-SHA256 (`salt`,
   `rounds`, 32 bytes).
2. Every canvas route then takes `session=ID` too: `/canvas?session=ID`,
   `/canvas?after=N&session=ID`, `/canvas/N?session=ID`. The answer is the
   same canvas text, sealed with the session's key, written as hex and a
   newline. A session unused for `session-seconds` ends; a request in it is
   then `403`, and the viewer starts a new one.

Sealed means AES-256-GCM: a fresh 12-byte nonce, the ciphertext, the
16-byte tag, in that order. The additional data, never sent, binds each
seal to its session: the text `guide-feature session ID` for the key and
`guide-feature canvas ID` for a canvas. A seal that does not open is
refused, never shown.

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
- A mark from a version newer than the canvas is an error, like any other
  malformed line.

A viewer checks itself against `assets/test-canvases/`: canvases with the
grid, mark ages and changed cells each one must give, and canvases each one
must refuse.
