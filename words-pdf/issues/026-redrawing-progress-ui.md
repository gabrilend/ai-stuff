# Issue 026: Redrawing Progress UI With Color-Gradient Bar

## Current Behavior

`compile-pdf-ai.lua` prints status lines as it walks each page of the
book. For every page it emits something like:

```
  📝 Left poem 1: anarchist_theory (Tier 2)
  📝 Left poem 2: digital_resistance (Tier 2)
  ... (up to ~17 poem lines)
📖 Processing page 82/489 [███░░░░░░░░░░░░░░░░░] 16% complete
Analyzing page with 3084 characters of poem text...
🎨 Page theme selected: circuit (raw: 0.603, weighted: 0.464)
🎨 Page background theme: circuit
✨ Tier 1 art enabled: page is 53% full (threshold 65%)
🎨 Drawing circuit art in 4 outside region(s)
🎨 Generating circuit theme art
```

A 489-page book emits roughly 489 × 15 ≈ 7,300 lines into the same
terminal during a single run. The lines all `print()` straight to
stdout, which `./run` tees into `tmp/logs/run-*.log` while also showing
on the terminal. Two consequences:

1. The terminal scrolls past faster than a human can read. The
   progress bar itself flies by mixed in with poem lines, so it is
   hard to glance at the screen and tell how far along the run is.
2. The progress bar is a single monochrome string. It does not encode
   the completion percentage in any visually distinctive way beyond
   the count of `█` characters, which all look identical.

## Intended Behavior

The terminal output for the per-page loop becomes a fixed-height
region near the bottom of the scrollback that **redraws in place**
on each new page, instead of scrolling. The region contains:

- A colored progress bar whose fill color advances through a
  gradient as completion grows: dark blue → purple → cyan → yellow
  → green.
- The "Processing page N/M ... %% complete" header (white text,
  default terminal color).
- All per-page status lines (poem listings, theme selection, art
  decisions) underneath the bar, in their original wording.

Once a page with more status lines than any previous page is
encountered, the region grows by exactly that many lines and stays
that tall for the rest of the run. Lighter pages pad the region
with blank lines so the bar never jumps around.

The log file written by `./run` continues to receive every status
line in full sequential order with no ANSI escape codes, so
`cat tmp/logs/run-*.log` after the fact reads the way the live
terminal does today.

If `/dev/tty` is unavailable (the script is piped into something,
or run under a non-interactive harness) the redraw branches are
skipped and every line `print`s normally — i.e. today's behavior.

## Suggested Implementation Steps

1. Create `libs/progress-ui.lua` exposing:

   - `init(total_pages)` — open `/dev/tty` for writing (nil-tolerant);
     open `$LOG_FILE` for appending; initialize `max_region_height`,
     `current_buffer`, `pages_done`.
   - `start_page(page_num)` — if interactive and not the first page,
     emit `\27[<max_region_height>A\27[J` to jump back to the anchor
     and clear the previous frame. Reset `current_buffer`. Compute
     the gradient color for this page and push the progress bar line
     onto the buffer.
   - `log(text)` — append `text` to both `current_buffer` and the log
     file. Does not touch the tty until `end_page`.
   - `end_page()` — if interactive, write every buffered line to tty;
     either grow `max_region_height` or pad with blank lines so the
     cursor always lands exactly `max_region_height` lines below the
     anchor. If non-interactive, just `print` each line.
   - `finish()` — restore default colors, close the tty handle.

2. Compute the gradient color via a small dispatch table mapping
   `page_num / total_pages` to a 256-color ANSI code. No reds:

   | fraction | color code | name |
   |---|---|---|
   | 0.0–0.2 | 17 | dark blue |
   | 0.2–0.4 | 93 | purple |
   | 0.4–0.6 | 51 | cyan |
   | 0.6–0.8 | 226 | yellow |
   | 0.8–1.0 | 46 | green |

   Color only the filled `█` characters; leave `░` and the surrounding
   "Processing page N/M ... %% complete" text default.

3. In `compile-pdf-ai.lua`:

   - `require("libs.progress-ui")` near the top alongside other libs.
   - Call `progress_ui.init(total_pages)` before the page loop at
     `build_pdf`.
   - Call `progress_ui.start_page(page_num)` at the top of each
     iteration; remove the existing `print(string.format("📖
     Processing page ..."))` block (the module owns the bar now).
   - Replace every `print(...)` that fires during a page iteration
     with `progress_ui.log(...)`. The current set, from grep:
     - "Analyzing page with N characters" (in `build_color`)
     - "🎨 Page theme selected" (raw + neutral variants)
     - "  📝 Left poem N" / "  📝 Right poem N"
     - "🎨 Page background theme"
     - "✨ Tier 1 art enabled" / "🔍 Tier 1 art skipped"
     - "🎨 Drawing ... art in N outside region(s)"
     - "🎨 Generating ... theme art"
     - "🔍 No outside regions" / "🔍 Neutral page theme"
   - Call `progress_ui.end_page()` at the bottom of each iteration.
   - Call `progress_ui.finish()` after the loop, before the "✅ All N
     pages processed" print.

4. In `./run`:

   - `export LOG_FILE` (it already exists as a shell variable; just
     promote it to the environment) so the lua module can `os.getenv`
     it.

## Relevant Files

- `compile-pdf-ai.lua` (page loop at the bottom of `build_pdf`,
  status prints scattered between roughly line 997 and line 2782)
- `libs/progress-ui.lua` (new)
- `run` (one `export` line)

## Design Notes

The redraw region is **append-only inside one page** and
**replace-only across pages**. Each `log()` call streams its line
to the tty immediately (so the user watches per-page work happen
in real time), while end_page handles the trailing-content /
truncation-indicator / padding bookkeeping. An earlier design
buffered everything for end_page to flush atomically, but that
left the screen visibly dark during the slow first-page
embedding initialization and during every subsequent page's
processing window — the old frame was wiped at start_page and
the new frame did not appear until end_page. Live-streaming
eliminates that dead window: the bar is repainted the moment
start_page fires and each status line appears as the underlying
code produces it.

Two parallel buffers (`tty_buffer` and `plain_buffer`) are kept in
lockstep — the only line that differs between them is the progress
bar itself, which carries ANSI color codes in the tty version and
plain text in the plain version. `log()` calls append the same
string to both. On flush, the interactive path consumes
`tty_buffer`; the non-interactive fallback consumes `plain_buffer`
so a piped/captured run gets clean text with no escape codes
bleeding into downstream tools.

The high-water-mark approach was chosen over a fixed-height region
because the number of poems per page is data-driven and varies
across the book. A fixed cap would either waste space on light
pages or truncate heavy ones. Letting the region grow once means
exactly one visible "lurch" during a run; after that it is stable.

There IS a fixed ceiling on top of the high-water mark, equal to
`(detected terminal rows) - 1`, enforced because the cursor-up
escape that anchors the next frame must not overshoot the visible
terminal top. If the cursor moves above row 1, the terminal
clamps it, and the follow-up clear-to-end-of-screen erases every
visible row including any persistent header above the frame —
which manifests as "the entire screen goes blank" the moment the
first page tries to render more lines than the terminal is tall.
When a frame would exceed the ceiling, the tail-most content
lines are dropped from the tty render and replaced by a
`… +N more lines (see log)` indicator. The log file still
receives every line in full.

`\27[0J` is used instead of bare `\27[J` because some terminals
default the parameter-less form to `\27[2J` (clear entire screen)
rather than mode-0 (cursor to end). The explicit "0" parameter
is universally unambiguous.

`io.stdout:flush()` and `io.stderr:flush()` are called once in
`init()` so any output that the parent shell tee'd through stdout
(e.g. the "Starting PDF generation" banner) reaches the terminal
BEFORE the module starts writing to /dev/tty. Without this flush,
tee can deliver stdout lines into the middle of the first redraw
frame and offset every subsequent cursor-up by the same amount,
gradually walking the anchor off-screen.

Explicit `progress_ui.log()` calls were chosen over monkey-patching
the global `print`. Monkey-patching would silently swallow any
unrelated `print` that happened to fire during the page loop —
including from third-party code paths that today look innocuous —
and would mean the same call site behaves differently depending on
whether `init()` had been called yet. The explicit form makes each
redraw-region line visible in a code diff.
