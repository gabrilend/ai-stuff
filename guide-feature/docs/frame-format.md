# Frame format

A frame is one voice's complete statement at one moment. It is written by a
thinker on an fg-sora machine as the body of a living rmail message, and it
is read by the page keeper on kuvalu.

## As an rmail outbox file

The thinker keeps exactly one outbox file, named `frame`, and rewrites it for
every new frame:

    to: guide

    voice: fg-sora-2
    frame: 41
    after-page: 17
    fitted-to: 40x4
    written: 2026-10-21T21:40:03Z

    the keeper fades lines nobody repeats
    sora-1 keeps circling the memory budget
    3B at Q4 fits 8 GB with room for a page

The `to: guide` line and the blank line after it belong to rmail and are not
part of the frame. Everything after them is the frame. rmail delivers only
that part.

## Fields

The frame is a block of header lines, one blank line, then the thoughts.

| Field | Type | Meaning |
|---|---|---|
| `voice` | string, the hostname | Which voice wrote this. The page keeper checks it against the rmail sender name and refuses a frame where they differ: it is an error, never quietly corrected. |
| `frame` | whole number, starting at 1 | This voice's frame counter. Goes up by one per frame written. A jump of more than one means rmail skipped intermediate edits (`docs/rmail-constraints.md`), which is expected and counted. A number that goes down or repeats means the thinker restarted without its state and is reported as an error. |
| `after-page` | whole number, 0 for none | The number of the page the voice read before writing this. It lets the page keeper and viewers see how stale a voice's view was. |
| `fitted-to` | two whole numbers, `WIDTHxHEIGHT` | The voice's share of the display box that this frame was checked against (`docs/display-box.md`). The page keeper checks the frame against the box it currently holds, which may have changed while the frame was in flight. |
| `written` | text, UTC time as `YYYY-MM-DDThh:mm:ssZ` | When the thinker finished the frame. |

The headers appear in exactly this order, and each appears once. A header
that is missing, repeated, out of order or unknown makes the whole frame an
error. The page keeper logs it and keeps that voice's previous frame. It
does not guess.

## Thoughts

Each non-empty line after the blank line is one thought.

- **A thought is one row of the display box.** It may be at most the box
  width, counted in characters (UTF-8 code points, not bytes), and never
  wraps.
- **A frame may be at most the voice's share of the box height** in thoughts.
- These limits come from the display box (`docs/display-box.md`). They are
  never fixed numbers in code.
- A frame that does not fit is not cut down to size. The thinker's fit
  checker sends it back to the language model with a message that says
  exactly which lines are too long, by how much, and how many lines are over,
  and the model tries again (`docs/datapath-thinker.md`). The page keeper
  runs the same check on arrival, because the box can shrink while a frame is
  travelling. A frame that fails there is refused and logged, and the voice's
  previous frame stays.
- Thoughts have no identifiers. A thought is recognised as "carried forward"
  by how similar its words are to thoughts in earlier frames
  (`docs/datapath-relevance.md`), not by an id. A language model cannot be
  trusted to copy ids exactly, but it does reword things.
