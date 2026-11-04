# measure-centering-effect.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/measure-centering-effect: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Does subtracting the corpus mean improve POEM-to-POEM neighbour lists, the way
it demonstrably improves word-to-poem ones?

General description (for a CEO): the machine that turns writing into numbers
gives almost every piece a large common component, regardless of what it says.
Removing that shared part before comparing is cheap and reversible, but it
changes which poems the site calls "similar", so it should be measured rather
than argued about. This runs the comparison both ways over a sample and reports
what actually differs.

Usage:
  scripts/measure-centering-effect [--dir PATH] --model NAME [--sample N]
    --dir PATH   project folder (default below)
    --model NAME embeddings directory name (required: a model is always
                 named, Issue 10-065; it used to default to embeddinggemma-300m)
    --sample N   how many poems to compare all-against-all (default 2500)
  A word with no flag in front of it stops the script (Issue 10-076).

Cost grows with the square of SAMPLE. 2000 takes a couple of minutes; 4000
takes roughly four times that. The published figures were stable between the
two, so there is little reason to go higher.

Three measurements, because "better" needs more than one witness:

  [A] HUBNESS. Count how often each poem turns up in somebody else's top-K.
      A handful of poems appearing in hundreds of lists are hubs -- they flood
      the similar pages and crowd out real neighbours. This is the pathology
      centring is supposed to relieve, so it is the first thing to check.
  [B] DISPLACEMENT. How much do the neighbour lists change at all? If they
      barely move, the question is moot regardless of [A] and [C].
  [C] LEXICAL AGREEMENT. A weak but independent signal: do the neighbours share
      distinctive vocabulary with the query? Rare shared words are evidence two
      texts are about the same thing, arrived at without the model's help.
      Used only to COMPARE two scorings of the same corpus, never as truth.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `read_all(p)`
(No comment above it in the source.)

### `unit_set(subtract_mean)`

```
Two sets: as-is, and mean-subtracted. Normalising up front turns the inner
loop into one multiply-add per dimension instead of three.
```

### `neighbours(U)`
(No comment above it in the source.)

### `hub_stats(lists)`
(No comment above it in the source.)

### `words_of(txt)`
(No comment above it in the source.)

### `lexical_score(lists)`
(No comment above it in the source.)

### `overlap(l1, l2)`
(No comment above it in the source.)
