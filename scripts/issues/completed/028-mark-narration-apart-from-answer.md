# Issue #028: Mark in-progress narration apart from the final answer

**Status: shipped.** Blocks are kept apart instead of joined, and every block
but the last carries a quote marker. A turn holding a single block is treated
as an answer, not narration. The marker is applied after wrapping and
positioning, at a measure two columns narrower, so a quoted line's right edge
lands level with an unquoted one's.

## Current Behavior

Between two user turns the model usually speaks several times. It says what it
is about to do, reports what it found, corrects itself, and then — after the
last tool call returns — writes the considered answer. Every one of those
blocks is prose the model wrote for the user to read, which is why the
exporter keeps them all rather than keeping only the last.

It keeps them by **joining** them. The routine that flushes an assistant turn
concatenates every accumulated block with a blank line between and renders the
result as one section. The join is lossy in a way the blank line cannot
signal: a sentence written before the work was done and a sentence written
after it was finished read identically.

This is visible in the Double Diaper Dungeon transcript, where a single
response section opens with `I'll find the vision file under the project's
notes directory and read it` and continues, two paragraphs later, into
findings that only exist because that read had happened. Nothing in the file
says a quarter of an hour and eleven tool calls separate them.

### Why this matters more than it looks

The narration is the part of the record that shows *how* a conclusion was
reached — the wrong turn taken, the thing checked and discarded. The answer is
the part that shows *what* was concluded. A reader looking for one is
obstructed by the other, and a reader who cannot tell them apart may take a
guess written mid-investigation for a finding.

## Intended Behavior

Every block but the last is marked as narration with a leading quote marker.
The last block — the answer — stands plain.

    ### Assistant Response 7

    >           I'll find the vision file under the project's notes
    >        directory and read it, then give you my take.

    >        Love2D 11.5 and LuaJIT 2.1 are installed, and both
    >               project paths point at the same directory.

                  The vision holds together. Three things stood out,
                    and one of them genuinely worries me.

Blocks stay separate rather than being joined, because the boundary between
them is the thing being recorded.

### On reusing the quote marker

The quote marker already carries a meaning in this format: issue #026 (now
completed) renders a line the user pasted back from an earlier answer as a
blockquote, so the record shows which sentence a reply was aimed at.

The two uses cannot be confused, because they cannot occur in the same place.
A pasted-back line appears only inside a `### User Request` section — it is
something the user typed. Narration appears only inside a `### Assistant
Response` section. The section heading disambiguates them completely, and no
third meaning may be given to the marker without breaking that.

### A response with only one block

When the model spoke exactly once between two user turns, that block is the
answer and is not marked. Marking it would claim a distinction the session did
not make.

### A response with no answer

A turn can end with narration and no final block — the session was
interrupted, or the model was still working when the log was written. Then
every block is narration and every block is marked. This is the same shape the
race guard in issue #020 watches for, and the two must agree about it rather
than each deciding for itself.

## Suggested Implementation Steps

1. Stop concatenating the accumulated blocks at flush time. The list already
   exists and already preserves order; the join is what discards the
   boundaries.
2. Render each block through the existing formatter separately, then mark all
   but the last.
3. Apply the marker after wrapping and padding, so the measure is not thrown
   off by the two columns the marker occupies. See issue #027 step 2 — this is
   the same ordering constraint one step further along.
4. Treat a single-block turn as an answer, not as narration.
5. Keep the question-and-answer blocks rescued from the question tool
   (issue #019) in their existing position in the list. They are neither
   narration nor answer but a recorded decision, and joining or marking them
   would misrepresent them; they render as they do today.
6. Test the four shapes: one block, several blocks ending in an answer,
   several blocks with no answer, and a turn containing a rescued question
   block among ordinary prose.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the accumulation list and the two flush
  points, mid-stream and final, which must stay in agreement
- `issues/completed/026-mark-quoted-lines-in-transcripts.md` — the other
  meaning of the quote marker, and why the two do not collide
- Issue #027, which shares the padding measure this marker sits beside
- Issue #019, whose rescued blocks travel in the same list

## Notes

Requested directly by the developer while reviewing the Double Diaper Dungeon
transcripts, alongside #027.
