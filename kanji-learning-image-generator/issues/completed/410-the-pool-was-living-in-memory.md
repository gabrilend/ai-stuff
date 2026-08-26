# 410 — The pool was living in memory

## Current behavior

Done. The pool is `pool/` at the project root; the companions are tracked and
the pictures are not; and a companion whose picture is missing is a supported
state that the report explains rather than a gap it counts.

## Was

`405` says, in `src/045`, in `docs/042` and in its own text:

> **Nothing is ever deleted.** Not the bad ones. A low tier records what missed
> and by how much. Storage is cheap and judgement is expensive, and this trades
> the cheap thing for the expensive one deliberately.

And `input/settings.lua` puts it in `tmp/shared-memory/pool`, which is a symlink
into `/dev/shm`, about which this project's own `.gitignore` says:

> Nothing under it is the record.

Both of those cannot be true. The machine was restarted and the argument was
settled: every picture generated, and every rating given to one, was gone.

Nothing warned. The pool simply came back empty, and an empty pool looks exactly
like a pool nobody has filled yet.

## Intended behavior

**The pool lives on the disk, because that is what its own first paragraph
requires.**

`pool/` at the project root. The RAM tiers stay exactly what they are for --
things the run scripts recreate, which is what `docs/006` and the ignore file
have always said they are.

**And the judgement goes into the record, while the pictures do not.**

The two halves of a pool entry are not the same kind of thing and the reboot
made that obvious:

- A **picture** is large, and this project guarantees it can be made again --
  same description and same seed produce the same bytes, which `302` established
  and `408` already depends on. It is reproducible, so losing one costs time.
- A **companion** is a few hundred bytes of text, and it holds something no
  amount of time reproduces: what a person thought of the picture. There is no
  seed that regenerates somebody's opinion.

So the companions are tracked and the pictures are not. That is the same trade
the pool's own first paragraph makes, applied one level up: keep the expensive
thing, let the cheap thing be remade.

**The pair still travels together on disk**, which is the property `docs/042`
actually needs -- copy the folder and the tier, the seed and the origin all come
with it. Git not tracking one of the two files does not separate them; it only
declines to carry a copy.

**A pool that is empty because it was emptied should not look like a pool nobody
has filled.** If companions are present with no picture beside them, that is a
set waiting to be regenerated, and the report should say so rather than counting
them as missing.

## Suggested implementation steps

1. **Move the default in `input/settings.lua`**, and say in the comment why it
   is not in the RAM tier like everything else -- otherwise somebody tidying up
   will move it back for consistency.

2. **Ignore `pool/**/*.png` and `pool/**/*.gif`, track the rest.**

3. **The walker notices a companion with no picture** and the counting utility
   reports those separately, so a fresh clone can be told: here is what was
   judged, and here is the command that makes the pictures again.

4. **Test that a pool survives its pictures being deleted** -- which is the
   thing that happens on a fresh clone, and is now a supported state rather than
   a broken one.

## Related

`405` — the promise this breaks. `docs/006` — what the RAM tiers are for.
`302` — the determinism that makes a picture cheap and an opinion expensive.
