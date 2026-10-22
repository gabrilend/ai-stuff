# Datapath: how changes land on the shared canvas

All three voices are "blitting to the same 2d character array". This
document is how the blitter on kuvalu applies one voice's edit to the shared
canvas, in both merge modes, and how changes get marked so a person can skim
them.

## The three canvases involved

| Canvas | What it is |
|---|---|
| **base** `B` | the version the voice started its turn from (its `base:` header), read from the history |
| **voice** `V` | the edited canvas the voice sent |
| **current** `C` | the shared canvas now, version N, which may already include other voices' edits made after `B` |

The voice's changes are found by comparing `V` with `B`, never with `C`.
That way only the words this voice actually changed are applied, and another
voice's edit that landed in the meantime is not undone. (Owner's choice,
2026-10-21.)

## Words

A word is a run of characters with no space in it, at a row and a starting
column. Every canvas is turned into a list of words, each a record of row
(whole number), column (whole number), text (string) and length in
characters (whole number).

## Step 1 — what the voice changed

Compare the words of `B` and `V` by position:

- **kept**: the same text at the same row and column in both. Not a change.
- **written**: in `V` but not identically in `B`. It is new, or different,
  or moved.
- **removed**: in `B` but not identically in `V`, and its cells in `V` hold
  only spaces. The voice erased it.

A word in `B` whose cells in `V` are covered by written words is not
"removed". It is handled by the overwrite rule in step 3.

## Step 2 — removals

For each removed word: if `C` still holds exactly that word at that place,
its cells become spaces. If `C` has something else there now, another voice
changed it after this voice's base. That is left alone and counted as a
conflict.

## Step 3 — writes, and the whole-word rule

For each written word, in reading order:

1. Its characters are written into its cells of `C`.
2. Any word in `C` (as it was before this write) that lost **some but not
   all** of its letters to the write is blanked entirely: all of its cells
   that the write did not cover become spaces. A word that lost all of its
   letters is simply gone under the new one.

So no fragment of a word is ever left on the canvas. The owner's words: "if
any letter in a word is overwritten and can't fit, then that word is deleted
entirely."

Example, on one row:

    before:          the cat sat on the mat
    write "kitten" at the column where "cat" starts
    "kitten" covers all of "cat" and the "sa" of "sat"
    after:           the kitten   on the mat

(This reading of the rule is waiting for the owner's confirmation. See
`docs/open-questions.md`.)

## Step 4 — marks

Every cell written or blanked in steps 2 and 3 gets a `word` mark with the
voice's name and the new version number N+1. The other words of each
sentence that holds a marked word get a `sentence` mark. That is how "that
sentence would be marked as 'changed'" reaches the viewer. Marks and sentences
are defined in `docs/canvas-format.md`. A newer mark replaces an older one on
the same cell, and marks older than a set number of versions are dropped.

## Step 5 — publish

If any cell changed, `C` becomes version N+1 and is published
(`docs/datapath-round-trip.md`). If nothing changed (the voice sent its base
back untouched), no new version is made. The unchanged turn is counted.

## Merge modes

The mode is a setting in `input/blitter`, read on every arrival, so it can
be switched while running. Both modes must be built and tested.

### `newest` (the original design)

Each arriving voice canvas goes through steps 1–5 straight away.

### `distill`

kuvalu "will run all three combined to distill it once more". The blitter
keeps the newest canvas from each voice. On each arrival:

1. It builds a prompt holding the current canvas `C`, each voice's newest
   canvas with the words that voice changed listed under it, and the same
   rules the voices follow (change as little as possible, single words before
   sentences).
2. It asks the `distiller` endpoint (`docs/endpoints.md`) for one edited
   canvas, under the same fit check and retries as a voice's turn
   (`docs/fit-check.md`).
3. It blits that canvas with `C` as its base, through steps 1–5. Its marks
   carry the voice name `kuvalu`, unless the owner prefers marks to name the
   voice whose idea each change came from (an open question).

Distilling takes as long as a turn, so arrivals that come in meanwhile wait.
Only each voice's newest canvas is kept, so a queue cannot build up.

## Settings

Mark lifetime in versions, merge mode. Kept in `input/blitter`; changes to
their values go into `docs/balance-updates.md` with the reason.

## Why one thread

A canvas is a few thousand cells and a few hundred words. Comparing and
blitting takes microseconds. The slow part, distilling, waits on a language
model over the network, so there is nothing for extra threads to do.
