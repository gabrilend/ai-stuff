# The shape of a fact

What extracted data looks like once it is out of the archive. Lua tables, one
record per thing, with that thing's entire history folded inside it.

## The record

A record is one entity - an ability, an item, a statistic, a talent - and it
carries every version of itself that has ever been observed.

    return {
      kind = "ability",
      id   = 257044,
      line = "wow",
      name = "Rapid Fire",

      history = {
        { build = 22810, set = { cast_time = 0, coefficient = 0.96 },
          confirmed_at = { 22900, 23171 } },
        { build = 23360, set = { coefficient = 1.02 },
          confirmed_at = { 23420, 24015, 24461 } },
        { build = 25848, set = { coefficient = 1.02, ticks = 7 },
          confirmed_at = {} },
      },
    }

Field by field, down to primitives:

| Field | Type | Meaning |
|---|---|---|
| `kind` | string | which sort of entity this is; decides which extractor may write it |
| `id` | integer | the game's own identifier for it |
| `line` | string | which game line this history belongs to - retail and each Classic line are separate histories, because the same identifier means different things in each |
| `name` | string | the name as of the newest build that stated one; convenience only, never compared against |
| `history` | array | entries in ascending build order |
| `history[n].build` | integer | the build at which this value was **first** observed |
| `history[n].set` | table | only the fields that **changed** at that build; keys written in sorted order |
| `history[n].confirmed_at` | array of integer | every later build at which this same value was looked at again and found unchanged |

## Why changes rather than full copies

The timeline scrubber's question is "what changed in this patch", and a delta
answers it by being read. The alternative - a full copy of every field at every
build - answers it only by comparing two copies, and costs the archive a
complete duplicate of everything that stayed the same, which for a spell that
was untouched for six years is six years of identical rows.

The price is that "what was the full state at build B" requires walking from the
start of the history to B and applying each entry in turn. That walk is over
tens of entries, not thousands, and it happens once when the scrubber lands on a
build rather than on every frame of a drag.

## Why `confirmed_at` exists, and why it is not optional

A gap between two entries is ambiguous in a way that will silently corrupt every
conclusion drawn from this archive if it is not recorded.

If the coefficient was 0.96 at build 22810 and 1.02 at build 23360, there are
two very different situations that produce exactly the same two entries:

- We looked at every build in between and it was 0.96 the whole way, then
  changed. **The change happened at 23360.**
- We only ever looked at those two builds. **The change happened somewhere in a
  window six months wide, and we do not know where.**

Without `confirmed_at`, those are indistinguishable, and a chart drawn from this
data would place every change at the moment we happened to look rather than the
moment it happened. That is not a small error; it is an error that makes the
whole patch axis a record of our sampling schedule instead of the game's
history.

So every re-observation is written down even when nothing changed, and the
viewer is required to draw an unconfirmed window differently from a confirmed
one. This is the standing rule that a fallback is a warning and a warning is an
error, applied to time: we do not quietly assume a value held across a period we
never looked at.

## Sorted on write

Keys inside `set` are written alphabetically; history entries are written in
ascending build order. Neither matters to Lua, which does not preserve key order
in a table anyway. Both matter enormously to git, because a record re-written
with its keys in a different order produces a diff that touches every line and
says nothing. Sorting on write is what makes "this ability changed" a
three-line diff.

## Open sub-question: how records are grouped into files

One file per record is maximally specific and produces a file count in the
hundreds of thousands, which is its own kind of unusable. The natural seam for
abilities is the specialisation that uses them, because that is also the unit
theorycrafting thinks in and the unit the simulators load. Items likely split by
the content they drop from; statistics are few enough to share one file.

Not yet decided. It interacts with the megabyte cap from the archive document.
