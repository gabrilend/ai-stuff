# 205 — One canvas for each screen

phase 2, the canvas for viewers

## Current behavior

The canvas size is a setting the blitter reads at start (107). The owner's
first request asked for the size to "dynamically adjust to various size
screens".

## Intended behavior

**One canvas per watched screen.** The owner: "we could have one output for
each screen currently watching." A screen that opens with a canvas cached at
another size (the phone, after the computer was being watched) shows a
loading animation until a canvas is made at its own size. Every screen's
canvas is written from the same context, but written once for each screen.
Because no canvas is ever resized, no words are ever cropped by a moving
edge.

**Three screen modes**, a setting, exactly one active at a time:

| Mode | Canvases made per context change | What the bigger screens show |
|---|---|---|
| `round` (default) | one per watched screen, one after another, largest first | their own canvas, filling the window |
| `asynchronous` | one per watched screen, all at once on separate endpoints | their own canvas, filling the window |
| `smallest` | one, at the size of the smallest screen being watched | that same canvas, centred left-to-right and top-to-bottom in the window, its letters enlarged up to a set maximum |

The owner on `smallest`: "it doesn't reprocess for each screen ... it just
scales down the larger screens output to suit the smallest currently active
screen. So it would center justify and scooch down to the center of the
window on the desktop, with like... 4 lines of 10 characters or whatever the
watch can do. We can also increase font size but with a certain maximum."
The centring and enlarging are the viewer's work, not the blitter's: every
viewer is handed a canvas no larger than its window and draws it in the
middle, at the largest letter size that fits and is no larger than the
maximum (a setting in each viewer, in points or pixels per character).

**One round, largest first.** When the context changes, the screens are
refreshed one after another, largest first, smallest last. The context may
not change again until every watched screen has been refreshed. If the world
moves on mid-round ("the raccoon climbed onto the chandelier somehow while
we're still updating the watch screen"), the round finishes on the old
context and the new one waits: "it might cause a mess before we can update
ourselves on the new circumstances. That's okay."

**Asynchronous mode**: "updates all of them at once, but runs them in
separate but equal context windows on remote machines." It costs more
endpoints in exchange for no waiting. Like any mode, none of the three is
done until all three are tested on the same scripted series.

**The exact shape.** The owner's direction: "resizing is a visual thing. Every chance we get we
provide the current window size to the LLM and force it to match." Each turn
is given an example canvas of lorem-ipsum words built to the exact size,
"this is the exact shape you'll need to fill": every row has a letter in its
final column and every row ends on the end of a word. The example is made
fresh for each turn, at that turn's size. A reply too large is cut at the
edge, "even in the middle of the word!", and handed back: "this is all that'd
fit, please rephrase the sentences prior to the broken lines".

A cut reply is never published: the turn keeps asking until a reply fits
(404).

**Every voice paints every screen's canvas.** The owner: "one canvas, one
screen. Should be the same subject they're painting, but with two separate
brushsizes on two separate papers." Each screen's canvas has its own
history, base versions and marks, and the voices work on it exactly as on a
single canvas. The context, the subject they paint, is the same for every
screen. So a round over three watched screens with three voices is nine
turns in `round` mode, nine at once in `asynchronous` mode, and three in
`smallest` mode.

## Suggested implementation steps

1. Settle the questions above with the owner.
2. The exact-size example builder: given a width and height (whole numbers),
   a list of rows (strings) of lorem-ipsum words, each row exactly the width
   long and ending on a word's end.
3. The screen list: each watched screen's name (string), width and height
   (whole numbers) and whether it is being watched (true or false), sent by
   the display programs; sorted largest first.
4. The round: refresh each watched screen's canvas in that order; hold
   context changes until the round ends.
5. The loading state a display shows while its size has no canvas yet.
6. Asynchronous mode: every screen's canvas made at once on separate
   endpoints.
7. Smallest mode: one canvas at the smallest watched size; in every viewer,
   draw a smaller canvas centred in the window, at the largest letter size
   that fits, capped by the viewer's maximum.
8. The mode setting, read on every context change, and the three modes
   tested on the same scripted series.

## Related documents

- `docs/roads-not-taken.md`, "The box follows the smallest viewer"

## Open questions

- None left.

## Blocked by

107.

## Blocks

206.
