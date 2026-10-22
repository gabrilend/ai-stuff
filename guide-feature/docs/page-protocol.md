# Page protocol

The page protocol is the one thing every viewer depends on. It is written so
that a viewer can be built in any language (Lua, a shell script, Kotlin on
Android, Swift on the Apple Watch, JavaScript in a browser) from this page
alone, without reading any guide-feature source.

The same page text is also the body of the living rmail message the page
keeper sends back to the three voices, so the voices read exactly what people
see.

## The page text

    page: 18
    built: 2026-10-21T21:40:41Z
    box: 40x16
    share: 40x4
    voices: fg-sora-1 fg-sora-2 fg-sora-3
    over-box:

    fg-sora-1 40 1.000 the memory budget decides model size
    fg-sora-2 41 1.000 the keeper fades lines nobody repeats
    fg-sora-2 41 1.000 3B at Q4 fits 8 GB with room for a page
    fg-sora-3 12 1.000 nobody checked which C library they use
    fg-sora-2 38 0.640 split the page into pages when it fills
    fg-sora-1 33 0.120 random files make the voices wander

### Header lines

| Field | Type | Meaning |
|---|---|---|
| `page` | whole number, starting at 1 | Goes up by one each time the page changes. A viewer that has seen page N only needs to redraw when it sees a larger number. |
| `built` | text, UTC time `YYYY-MM-DDThh:mm:ssZ` | When the page keeper built this page. |
| `box` | `WIDTHxHEIGHT`, whole numbers | The display box in characters (`docs/display-box.md`). Every thought line fits the width, and there are never more thought lines than the height. A viewer with more room draws the box inside it; a viewer with less room should say its size in its request (below). |
| `share` | `WIDTHxHEIGHT` | The part of the box each voice's newest frame must fit. The voices read this to know how much they may write. |
| `voices` | names separated by single spaces | The voices this page has room for, in display order. A voice that has never sent a frame is listed but has no thought lines. |
| `over-box` | names separated by single spaces, or nothing | Voices whose current frame was written for a bigger box and is shown only in part until their next frame. Usually empty. |

Then exactly one blank line.

### Thought lines

One thought per line, four fields separated by single spaces. The fourth field
is the rest of the line, so it may contain spaces:

| Position | Field | Type | Meaning |
|---|---|---|---|
| 1 | voice | string, no spaces | Who wrote the thought. |
| 2 | frame | whole number | Which of that voice's frames it was last seen in, by the voice's own count. |
| 3 | relevance | decimal, always three places, `0.000` to `1.000` | How present the thought still is. `1.000` = in the voice's newest frame. Lower = fading. Viewers turn this into opacity, size, colour or position as they like. |
| 4 | text | UTF-8 to the end of the line, at most the box width in characters | The thought. Never contains a newline. |

Lines come in two groups, matching the parts of the display box:

1. **The newest frames**, relevance 1.000: each voice's thoughts in `voices`
   order, and within a voice in the order the frame gave them. At most
   `share` height lines per voice.
2. **The fading thoughts**, relevance below 1.000, highest first, as many as
   fit in the rows of the box that are left.

A viewer may re-arrange them, but this order is the page keeper's idea of
what matters most. Thoughts with relevance 0.000 are not listed: they have
left the page. Fading thoughts that did not get a row are not listed either,
but they are still tracked, and one can come back into sight if a voice
brings it up again.

## How to get it

Two transports carry the same text byte for byte.

### On kuvalu: files

In the project's RAM folder, `tmp/shared-memory/page/`:

| File | Contents |
|---|---|
| `current` | The newest page. Replaced as a whole by rename, so a reader never sees half a page. |
| `history/NNNNNN` | Every page ever built this run, six-digit zero-padded page number. Never rewritten. |

A local viewer waits for `current` to change (inotify, or reading it once a
second and comparing the `page:` line), then reads it.

### From anywhere: HTTP

The page server on kuvalu listens on a port set in its input file (not yet
chosen, see `docs/open-questions.md`).

| Request | Answer |
|---|---|
| `GET /page` | The newest page, `text/plain; charset=utf-8`. |
| `GET /page?after=N` | Waits up to 60 seconds for a page numbered above N, then answers with it. If none comes, answers `204 No Content` and the viewer asks again. This lets a phone or watch hear about a new page without polling every second. |
| `GET /page/N` | Page number N from history, or `404` if this run never built it. |

Any of these may add `box=WxH` (for example `GET /page?after=17&box=20x8`)
to say how many characters the viewer can show, and `viewer=NAME` to name
itself. The page keeper uses these only under the `smallest-viewer` and
`named-viewer` box rules (`docs/display-box.md`). The answer is still the one
shared page, not a page cut to this viewer's size.

There are no other routes. Anything else is `404`.

## Rules a viewer must follow

- Read the header and the blank line before any thought line. A page whose
  header is malformed is an error to show, not to work around.
- Never compute relevance. Show what the page says.
- A viewer may remember older pages to animate changes (a thought's relevance
  dropping from 0.640 to 0.520 can be drawn as a fade), but the newest page is
  always the truth.
