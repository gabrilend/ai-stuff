# 103 — The shape of a hover

## Current behavior

Nothing exists.

## Intended behavior

**The hover record is defined once, and real ones can be captured from real
pages and saved as files.** The fields are in `docs/002-datapath-the-hover.md`.

This issue is the contract between the page side and the host. Everything in
phase 1 is tested against saved hover records, so they have to be real: words
wrapped by a real browser, at a real window width, with the boxes it actually
drew. Invented geometry would test an imagined line-breaker.

**The capture tool is a static HTML page with one small script**, opened
directly in Firefox. It holds several paragraphs containing quantities (copied
from encyclopedia articles, recipes, engineering notes, news). When the pointer
enters a word, it builds the hover record exactly as the extension will, shows it, and
offers it as a file to save into the fixtures folder.

**The measuring code is written once and reused by the extension in `202`**,
not copied: the capture page and the content script load the same file.

**There is no waiting time before a hover is sent.** The owner's answer to how
long the pointer must rest: "however long it takes to generate". A hover record
is built the moment the pointer enters a new word, and the only wait the reader
sees is the picture being made. Words that are not quantities cost one short
message and a "no quantity here".

## Suggested implementation steps

1. `src/` — the page-side measuring script: find the paragraph element, walk
   its text nodes, measure each word's rectangles with a text range, group them
   into lines by vertical centre, find the pointer's word. JavaScript, because
   it runs in the page; kept to measuring only.
2. A word broken across two lines by hyphenation has two rectangles. It is
   recorded on the line where its first character sits, and the second
   rectangle is kept as a second box in the record — measuring it away would
   make the proximity of the next line's first word wrong.
3. `src/` — the capture page, and a fixtures folder of saved hover records.
4. `src/` — a Lua reader for the record that refuses a record with a missing
   field or a word whose `char_start` does not match `paragraph_text`. Wrong
   records are errors at the boundary, so nothing downstream checks for them.
5. Capture at least twenty hovers across two window widths, including: pointer
   on the number, on the unit, on a non-quantity word, on a wrapped line.

## Related

`docs/002-datapath-the-hover.md` · blocks `104`, `106`, `202`
