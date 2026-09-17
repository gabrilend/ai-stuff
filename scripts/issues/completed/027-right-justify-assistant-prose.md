# Issue #027: Right-justify the assistant's prose

**Status: built, shipped, and withdrawn the same day. Do not rebuild it.**

This file sits in the completed directory because the work was done, not
because the feature exists. It does not. Anyone reconstructing this project
from these issue files should implement the *Intended Behavior* section below,
which describes where the idea actually landed, and should not implement the
padding described in *What Was Tried*.

## Current Behavior

Both speakers' prose begins at the left margin. A transcript says who is
speaking with the heading above each block — `### User Request 7` against
`### Assistant Response 7` — and with the quote marker that issue 028 puts on
in-progress narration. Nothing is repositioned, and no line carries a margin it
was not written with.

## Intended Behavior

**Alignment is a property of a view, and a transcript is data. The two are kept
apart.**

If the assistant's words should sit on the other side of the page, that belongs
to whatever renders a transcript — a stylesheet saying `text-align: right`,
which is a renderer's actual job — and never to the file on disk. The file
stays plain, wrapped, left-aligned markdown that reads correctly in a terminal,
an editor, a diff, a search index, and a web renderer alike.

This is the house rule about generation and viewing being separate concerns,
turning up in a place nobody expected to find it.

## What Was Tried

The assistant's prose was padded on the left so each line's right edge landed
at column 80, putting the two speakers on opposite sides of the page so the
turn-taking could be followed without reading a word. Padding went on the left
only, so no line gained trailing whitespace. Structure whose meaning is its
column position — fenced code, indented code, table rows, headings, rules — was
never moved.

It worked exactly as intended in a terminal, an editor and `less`. It was
withdrawn within hours of shipping.

### Why it was withdrawn

**The stated reason, known in advance and accepted anyway.** In markdown, four
or more leading spaces means *code block*. Right-padded prose therefore renders
as a monospace box in any markdown renderer — which is how these files look on
GitHub, where the developer went to read them. The cost was written into this
file before the work started and judged acceptable on the grounds that
transcripts are read in terminals. That judgement was wrong, because it assumed
the reading happens where the writing happens.

**The real reason, visible only once the first one bit.** A transcript is the
*record* of a conversation; where the words sit on a page is a *presentation*
of that record. Baking presentation into storage hands every future reader one
viewer's preference, and the single renderer that disagrees — which turned out
to be the commonest one — cannot be overruled without rewriting every file.

**A third cost, unanticipated.** Right-justifying a wrapped list item destroys
its hanging indent, because a ragged-left edge and a fixed indent are two
different pictures and only one can be on a page. Removing the padding restored
the hanging indent on the assistant's side without anyone asking, which is a
fair sign the padding had been fighting the formatter rather than extending it.

## Suggested Implementation Steps

Nothing to implement in the exporter. The work, if still wanted, lives in a
viewer:

1. A renderer for the transcript corpus — the HTML documentation pages this
   project already builds for other document kinds are the obvious home.
2. Alignment there is a stylesheet rule, so it can differ per reader, be turned
   off, or be changed later without touching a single stored file.
3. A viewer can also do what padding could only gesture at: narration in a
   genuinely different visual register rather than borrowing the quote marker,
   model provenance as a gutter down the side, and search across the whole
   corpus at once.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the wrapping routine, which is all that
  remains of this
- `tests/test-transcript-wrapping.sh` — asserts that nothing is padded; the
  absence is the feature, so it is tested like one
- `issues/transcript-system-progress.md` — where this reversal is recorded as
  part of the development journey
- Issue #028, which marks narration and is unaffected: the quote marker is real
  markdown that renders correctly everywhere, so it stayed

## Notes

Requested by the developer, built, and then withdrawn by the same developer
after reading the result on GitHub. The lesson was worth the day: the question
"where does this belong, the data or the view?" is worth asking before the work
rather than after a renderer answers it for you.
