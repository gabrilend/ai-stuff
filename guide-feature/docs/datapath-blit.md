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
   all** of its letters to the write is a **cut word**. What happens to a cut
   word is decided by the collision rule (below). A word that lost all of its
   letters is simply gone under the new one, whatever the rule.
3. A word in `C` directly touching the written word, with no space between,
   has lost no letters but would read as one word glued to it. It is a cut
   word too, so the rule decides: `blank-whole` blanks it, `keep-fragments`
   leaves the two run together (issue 106).

### Collision rules

The owner confirmed the whole-word rule as the default, and asked for room to
play: "yes, but we probably want to play around with it. Think of options to
give us for this functionality here." The rule is a setting in
`input/blitter`, read on every arrival, and each rule is one entry in a
table from rule name to function. Most promising first:

| Rule | What happens to a cut word | Why try it |
|---|---|---|
| `blank-whole` (default) | All of its remaining letters become spaces. No fragment is ever left. | The owner's rule: "if any letter in a word is overwritten and can't fit, then that word is deleted entirely." |
| `fade-fragments` | Its remaining letters stay, with an `orphan` mark. Viewers draw them dimmed, and they are blanked after a set number of versions unless a voice writes over or reuses them. | A cut turns into a fade instead of a vanishing, which is closest to the vision's "fade from the viewer's sight". |
| `keep-fragments` | Its remaining letters stay, unmarked, as a plain overwrite would leave them (like a terminal). | The baseline. It shows how much the other rules actually change. |
| `refuse-cut` | The write that would cut it is not applied at all, and a conflict is counted. To replace a word, a voice must first erase it. | The strictest restraint: nothing is destroyed by accident. |
| `push-aside` | The cut word slides right, along its row, to the nearest gap wide enough to hold it. If there is none, it is blanked. | Words survive collisions, at the cost of the row reshuffling. |
| `blank-sentence` | The whole sentence holding the cut word is blanked. | A sentence with a word cut out is broken anyway. This clears space fastest. |

The owner chose the next three to build after `blank-whole`: `fade-fragments`,
`keep-fragments` and `push-aside`. What a reader should see when two voices
want the same spot: "confusion, as it flips back and forth. Indecision is
valid. But, it should coalesce to a stable state over time, because the LLMs
are encouraged to change as little as possible." So the scripted test series
for each rule should show the flipping and then the settling: how many
versions pass before a contested spot stops changing.

Independently of the rule, **tell-the-voice** (on or off) lists the words a
voice cut in the next canvas it receives, so its next turn can see what its
edit destroyed.

Example, on one row, under `blank-whole`:

    before:          the cat sat on the mat
    write "kitten" at the column where "cat" starts
    "kitten" covers all of "cat" and the "sa" of "sat"
    after:           the kitten  on the mat

A shorter word written over a longer one is the same case seen from the
other side. `dog` written over the start of `kitten` cuts `kitten`, so its
`ten` is blanked under `blank-whole`, kept dim under `fade-fragments`, and so
on.

## Step 4 — marks

Every cell written or blanked in steps 2 and 3 gets a `word` mark with the
voice's name and the new version number N+1. The other words of each
sentence that holds a marked word get a `sentence` mark. That is how "that
sentence would be marked as 'changed'" reaches the viewer. Marks and sentences
are defined in `docs/canvas-format.md`. A newer mark replaces an older one on
the same cell, and marks older than a set number of versions are dropped.
Under `fade-fragments`, a cut word's leftover letters get `orphan` marks
instead, and when an orphan mark expires its cells are blanked.

Built in `src/020-marks.lua` (issue 201). It runs in the blitter before any
publisher, so every publisher gets the version with its marks. A blanked
cell between words belongs to the sentence `docs/canvas-format.md` gives it.
A cell that was already blank, and is only blanked again, gets no new mark.
Until `fade-fragments` is built, no blit makes orphans. The marker already
marks orphan cells and lists the ones whose marks run out. Blanking those
cells comes with `fade-fragments`.

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
   carry the voice name `kuvalu`. The distiller is not asked which voice
   each change came from. The owner: "The synthesis step takes 3 or more
   inputs and combines them. The provenance is inherently melded together
   like melting two candles to each other."

Distilling takes as long as a turn, so arrivals that come in meanwhile wait.
Only each voice's newest canvas is kept, so a queue cannot build up.

## Settings

Mark lifetime in versions, orphan lifetime in versions, merge mode,
collision rule, tell-the-voice. Kept in `input/blitter` (tell-the-voice,
which only shapes what is mailed to the voices, in `input/to-voices`: issue
303), and changes to
their values go into `docs/balance-updates.md` with the reason. Every
collision rule that is built is tested on the same scripted series as
`blank-whole`, because a mode is not done until it is shown working beside
the others.

## Why one thread

A canvas is a few thousand cells and a few hundred words. Comparing and
blitting takes microseconds. The slow part, distilling, waits on a language
model over the network, so there is nothing for extra threads to do.
