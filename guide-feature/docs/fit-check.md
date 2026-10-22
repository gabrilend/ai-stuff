# The fit check

Every edited canvas a language model writes is checked by machine before it
goes anywhere. A canvas that fails goes back to the model with a report
written like a compiler's errors, and the model tries again. The owner: "The
LLM is provided this knowledge, and if their output doesn't fit it is
returned mechanically and run again with a description of why. Like a
compiler error."

The canvas is the same size for every voice: "each machine gets access to
all of the rows. and columns. They are all working with the same canvas
size." What the check enforces is the size, and restraint: "they should try
and change as minimal as they can in order to keep the important stuff from
before displayed, while also fitting in new stuff. They should prioritize
editing single words over changing sentences."

## What is checked

Against the base canvas the turn started from:

| Check | Kind of error | Example report line |
|---|---|---|
| no row is longer than `W` characters | `too-wide` | `row 7: 64 characters, 4 over the width of 60` |
| there are exactly `H` rows | `wrong-height` | `the canvas has 22 rows; it must have exactly 20` |
| no more words changed than the change budget | `too-many-changes` | `you changed 31 words; at most 12 may change per turn` |
| sentences rewritten whole count against a smaller budget | `rewrote-sentences` | `you rewrote 3 whole sentences; at most 1 may be rewritten. change single words where you can` |

A word counts as changed when the word at that row and column is different
from the base, or is new, or was removed (`docs/datapath-blit.md` defines
this exactly; the fit check and the blitter use the same word comparison).

The two budgets are settings (`input/turn`). They are knobs. Changes to
them go into `docs/balance-updates.md` with the reason, once there is a
first change.

## The report

One line per problem, ordered by row, then a closing line restating every
limit:

    the canvas does not fit:
      row 7: 64 characters, 4 over the width of 60
      you changed 31 words; at most 12 may change per turn
    write the whole canvas again: exactly 20 rows, each at most 60
    characters, changing at most 12 words and rewriting at most 1 sentence.
    keep everything you did not mean to change exactly as it was.

## Where it runs

- **In each voice's turn**, before the canvas is mailed. On failure the
  report and the model's reply are added to the conversation and the model is
  asked again, up to a number of tries (a setting). When the tries run out,
  the turn sends nothing and counts a give-up. A canvas is never trimmed or
  cut down to make it fit.
- **In the blitter**, on arrival, for the size only. The budgets are the
  voice's business, but a canvas of the wrong size cannot be compared with
  its base at all, so it is refused and logged.
- **In distill mode**, on the distiller's reply, the same as in a voice's
  turn.

Width is counted in UTF-8 code points. Whether to count terminal columns
instead (some characters take two) is an open question.
