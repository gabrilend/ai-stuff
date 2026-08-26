# 038 — Rank for dropping, place for reading

**Pattern.** When something assembled from parts has to be shortened to fit,
give every part two separate numbers: how important it is, and where it goes.
Using one number for both is a bug that hides as a design.

## Where it came from

`025` builds a sentence for a diffusion model out of clauses, and the encoder
reading it stops after about seventy-five tokens — quietly, ignoring the end of
what it was given.

The first design used position for both jobs. A text encoder weighs the
beginning of a prompt most, so the important things went first; the photographic
terms that keep the model out of illustration went last and were protected; and
the sentence was shortened from the middle. Every one of those three statements
is true.

Together they were wrong. When the middle ran out, the next clause dropped was
whichever sat second from the end — and for the character meaning *rest*, that
was the person. The prompt came back describing a tree in a wood, having
silently deleted the etymology that is the entire reason the picture teaches
anything.

## Why one number cannot do it

Three requirements were in play:

- the etymology must survive shortening → it must rank high
- the photographic terms must survive shortening → they must rank high
- the photographic terms must be written last → they must be placed low

The second and third are contradictory in any scheme where position is
importance. No amount of reordering fixes it, because the conflict is not about
order — it is about there being two different orders that both matter.

## Where else it applies

Log lines under a size cap. Columns in a table too narrow for all of them. Items
in a menu that has to collapse. Fields in a summary. Anywhere the phrase "we'll
just truncate it" appears, there are two orders and only one of them is written
down.

## The tell

If you find yourself reasoning "drop from the middle" or "keep the head and the
tail", you have already noticed that importance and position disagree, and you
are encoding the disagreement in an algorithm instead of in the data.
