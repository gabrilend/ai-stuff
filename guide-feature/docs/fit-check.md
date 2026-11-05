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
| every character has a width: no tab or other control character, and only valid UTF-8 | `bad-character` | `row 4: a tab or other control character at column 2; use spaces` |

A row with a `bad-character` problem is not measured for width, and a reply
with one cannot be compared with its base, so it has no change counts. On
arrival, the blitter checks only that a voice's canvas is the size of its
base, which adds `wrong-width` (`the canvas is 64 characters wide; it must be
exactly 60`). Issue 105.

A word counts as changed when the word at that row and column is different
from the base, or is new, or was removed (`docs/datapath-blit.md` defines
this exactly; the fit check and the blitter use the same word comparison).

## The change budget is soft

Only the size is refused. How much a voice changes is advice, not a rule.
The owner: "as many as it'd like, but it's recommended to change fewer, and
focus on I think they're called 'operative words' like 'very' being replaced
to 'not very' or similar if something changes in magnitude or quality or
whatever."

So the turn prompt recommends a number of changed words and of whole
sentences rewritten, and asks the voice to reach first for the word that
carries the meaning's strength or direction ("very" to "not very", "often"
to "rarely"). A canvas over the recommendation is accepted. The counts are
written in the next canvas the voice receives, as a plain note, not an
error:

    last turn you changed 31 words (12 recommended) and rewrote 3 whole
    sentences (1 recommended). smaller changes to the operative words
    keep more of what is already here.

The two recommended numbers are settings (`input/turn`). They are knobs.
Changes to them go into `docs/balance-updates.md` with the reason, once
there is a first change.

## The report

One line per problem, ordered by row, then a closing line restating every
limit:

    the canvas does not fit:
      row 7: 64 characters, 4 over the width of 60
    write the whole canvas again: exactly 20 rows, each at most 60
    characters. keep everything you did not mean to change exactly as it
    was.

## Where it runs

- **In each voice's turn**, before the canvas is mailed. On failure the
  report and the model's reply are added to the conversation and the model is
  asked again, with no limit on tries: "it will just keep spinning until it
  gets it right." A reply too large is shown back to the model cut at the
  edge, even in the middle of a word, with "this is all that'd fit, please
  rephrase the sentences prior to the broken lines". The cut version is only
  ever shown to the model; it is never published. The number of tries is
  counted and logged, so a model stuck spinning is visible.
- **In the blitter**, on arrival, for the size only. The change counts are
  the voice's business, but a canvas of the wrong size cannot be compared with
  its base at all, so it is refused and logged.
- **In distill mode**, on the distiller's reply, the same as in a voice's
  turn.

Width is counted in UTF-8 code points. Whether to count terminal columns
instead (some characters take two) is an open question.

## The exact shape, and a reply cut to it

Every turn is shown an example canvas of lorem-ipsum words built to its
exact size, with the line "this is the exact shape you'll need to fill":
every row exactly the width, a letter in its last column, ending on a
word's end. The example is fresh for each turn (seeded by the turn), so a
model learns the shape and not the words.

A reply too large is cut at the edge, even in the middle of a word, and
rows past the height are dropped. The cut rows go back to the model with
"this is all that'd fit, please rephrase the sentences prior to the broken
lines", naming the rows cut and the rows dropped. A cut reply is never
published; the turn keeps asking until a reply fits (404). Built in
`src/027-exact-shape.lua` (issue 205).
