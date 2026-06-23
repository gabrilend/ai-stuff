# boost-bars.info.md

Draws the nested "boost" (reshared-post) frame as ASCII/box-drawing characters
wrapped in `<font>` color tags. It is the single source of truth for the boost
frame across every render path (main thread, effil worker, chronological page),
so the copies cannot drift. The frame is asymmetric: the left edge is always
double-line (it anchors the frame); the right edge is a "fill frontier" that is
single-line until the progress bar fills the far-right column, then double-line.
Arrows ride the corners — `◀═` into the top-left, `─▶` out of the bottom-right.

Think of it as a black box: give it a progress fraction, some content lines, and
the three nav links, and it returns the whole frame as one newline-joined string.

## Configuration

- **`M.configure(palette)`** — set the colors. `palette` is a table with hex
  strings: `arrow`, `outer_frame` (the blue ╔═╗ frame), `inner_box` (the teal
  ┌─┐ content box), `content_text` (the boosted text). Call once before drawing.
- **`M.CONTENT_WIDTH`** — read-only number (72). The visible content width inside
  the green box. Callers that pre-wrap long content or URLs must wrap to THIS so
  the lines fit (it is 72, not 74, because body lines are indented two columns to
  align under the arrow-pushed top corner).

## Drawing one line at a time

Each returns one frame row as a colored string. `progress_chars` is
`floor(progress_fraction * 78)`.

- **`M.top_border(progress_pct)`** → top row `◀═╦…[BOOST]…┐`. Takes the 0..1
  progress fraction; floats the `[BOOST]` label at the midpoint of the filled bar.
- **`M.inner_top(progress_chars)`** → `║ ┌────┐ │` (teal box opening).
- **`M.inner_bottom(progress_chars)`** → `║ └────┘ │` (teal box closing).
- **`M.content_line(content, progress_chars)`** → `║ │ <content> │ │`. Colors the
  text, pads it to `CONTENT_WIDTH` with uncolored spaces. `content` may contain
  HTML (links, markdown spans) — tags are ignored for the width count.
- **`M.nav_separator(progress_chars)`** → `╠──┐ … ┌──┤` (opens the nav boxes).
- **`M.nav_line(similar, different, chronological, progress_chars)`** →
  `║ similar │ … chronological … │ different │`. The three args are HTML anchor
  strings (or plain text); `chronological` may be nil to omit the center link.
- **`M.bottom_border(progress_pct)`** → `╚══╧══…══┴══╩─▶`. Junctions land under the
  nav-box walls (columns 12 and 69 = bar-index 10 and 67).

## Drawing the whole frame

- **`M.format_boost(content_lines, progress_pct, similar, different, chronological, include_nav)`**
  → the entire frame as one string (lines joined by `\n`). `content_lines` is an
  array of already-wrapped content strings (the caller owns wrapping). Set
  `include_nav` true to add the similar/different/chronological row; false to skip
  it (used on the simplified similar/different pages).

## Widths (for tests / verification)

Visible codepoint counts: `top_border` 82, `inner_top`/`inner_bottom`/
`content_line`/`nav_separator`/`nav_line` 82, `bottom_border` 84 (the extra two
are the trailing `─▶`). The framed rectangle is columns 2..81 on every row.

## Related

- `src/boost-bars.test.lua` — 70 char-counting assertions (width, frontier,
  junction columns, no ▢ corruption, assembly).
- `src/poem-bars.lua` — the analogous module for regular/golden poem bars; the
  golden poem shares the same fill-frontier idea.
- `issues/completed/8-057-boost-visual-formatting.md` — the design + history.
