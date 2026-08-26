# 405 — The pool that remembers

## Current behavior

Nothing is kept. A run overwrites its output directory and there is no record
that a picture ever existed, let alone whether it was any good.

## Intended behavior

**Every picture ever made, kept, with everything true about it beside it.**

```
pool/sky/06642-時-0f3a91.png
pool/sky/06642-時-0f3a91.info.md
```

**The pool is the filesystem.** No database, no index file, no schema. Two files
with the same stem in the same directory, and the convention this project
already uses for source files — a companion `.info.md` you read instead of the
thing itself — extended to what the project produces.

That buys three things and each is the reason for it:

- **Queries never open a picture.** *Which forest ones are good* is answered by
  reading small text files.
- **Nothing can be separated from its meaning.** Copy the pair anywhere and the
  tier, the seed and the origin travel with it. A central store drifts from what
  it describes the first time somebody archives one without the other.
- **The history survives.** Ratings are appended, never overwritten, so a
  machine's guess stays visible under the correction a person later made.

**Nothing is ever deleted.** Not the bad ones. A low tier records what missed
and by how much; re-rating later can promote something scored in a hurry; and a
pool that has been pruned cannot answer why the output drifted. Storage is cheap
and judgement is expensive, and this trades the cheap thing for the expensive
one deliberately.

**The category is the world**, because that is the unit somebody complains in —
*the forest ones are all the same tree*. A second axis says whether a rendering
is of a character or a phrase.

**Counts come from a utility.** How many exist at each tier, how often the
machine agrees with a person, how much elaboration is outstanding — none of
those numbers is ever written into a document. A number typed into
documentation was true once; a utility is true when asked.

## Suggested implementation steps

1. **The companion is markdown with a small table at the top**, because it has
   to be readable by a person and greppable by a program, and this project
   already reads and writes that shape everywhere else.

2. **Appending a rating rewrites the companion and nothing else.** No file is
   ever rewritten to change a tier that already exists.

3. **The walker is the whole query layer**: it reads companions, filters by
   category, tier, provenance and kind, and returns paths. Everything else —
   the dial, the graders, the gallery — is a caller of it.

4. **Test that a rating survives a re-read**, that the last one wins, that the
   earlier ones are still there, and that moving a pair to another directory
   loses nothing.

## Related

`docs/042` — the shape. `406` — who writes the tiers. `407` — who reads them.
