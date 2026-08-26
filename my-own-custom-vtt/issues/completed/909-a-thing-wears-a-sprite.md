# 909 -- A thing wears a sprite

**Phase:** 9, the sprite studio
**Blocked by:** [903](903-the-pool-keeps-everything.md), [904](904-two-ways-of-rating.md)
**Blocks:** [908](908-the-phase-nine-demo.md)
**Documents:** [the sprite studio](../../docs/017-the-sprite-studio.md),
[the dynamic picture](../../docs/012-the-dynamic-picture.md)

## Why this exists and why it is numbered last

It is foundational and it was written late, which is the wrong way round.

It surfaced while wiring `VERB_RETIER` for
[904](904-two-ways-of-rating.md): a person mid-session looks at a goblin, thinks
*that one is wrong*, and re-tiers it. The command needs to name a sprite. There
was nothing to name. A thing in the world carries a `kind`, and a sprite is made
from a category and a seed, and nothing connected the two.

Without this the sprite studio is a separate program that happens to share a
repository.

## Current behaviour

**Done.** A thing carries `sprite_category`, an offset into the world's string
pool, and `sprite_seed`. Together they are a whole description: hand them to the
sprite maker and the same picture comes back, byte for byte, forever. Zero in the
category means it wears nothing.

The furnishing stage asks the ruleset what it calls a kind, sanitises the answer
into a category — "Goblin Sentry" becomes "goblin-sentry" — and writes it down.
With no ruleset the category is the kind's number, "kind-3", which is a name
rather than an absence: the describe hook is optional and a world with no rules
layer is a supported world. A ruleset that answers with something that sanitises
away to nothing is a different case and generation refuses by name.

Seeds come from a stream of their own, so adding a draw elsewhere in furnishing
does not repaint every creature in every dungeon anybody has a seed for. A test
checks that things of one kind wear pictures that all differ, exactly — not
"mostly", because with 32-bit seeds any repeat inside a handful is either a
collision worth investigating or a seed shared by construction, and the second is
the bug it is looking for.

`VERB_RETIER` exists with three refusals of its own and runs the whole gauntlet:
no library attached, a tier off the scale, and a thing wearing nothing. Who may,
for now, is whoever may edit the world. Who rated it is recorded as a **seat**
rather than a display name — that field is display-only everywhere in this
project, and a library that outlives the session must not be keyed on something
somebody can change between one evening and the next.

### What the version bump uncovered

The converter ladder had never been tested against a change of record shape,
which is the thing it exists for.

A world file stores a checksum of itself, computed by walking every field of
every record — and the walk is whatever the current build's walk is. A version 2
file's checksum covered nine fields per thing; this build's walk covers eleven.
Recomputing it compares two different questions and always disagrees, so **every
version 2 file would have been refused as corrupt** and the ladder could never
have been used at all.

The check is now skipped for a migrated file, and the world records the version
it came from so a caller can say out loud that its integrity was not verified.
That is a loss, stated rather than hidden. Open question 15.4 names the real fix.

There is now a test that takes a current file apart into a version 2 one and
loads it — rather than keeping an old file in the repository, which would drift
out of date and end up proving that an ancient artifact still parses rather than
that the ladder works.

### And a crash worth keeping

Adding a verb without adding its row to the wire table left a row of zeroes with
no name, and the first thing to ask that row for its name walked into it. The
protocol test found it as a segmentation fault. There is now a test that names
the verb with no wire shape instead, and checks that the wire's name and the
command's name are the same word — two tables disagreeing about what a verb is
called is how a log and a protocol dump come to describe different sessions.

## Intended behaviour

**A thing carries the two things that name a picture**: which category, and which
seed.

| Field | Type | Meaning |
| --- | --- | --- |
| `sprite_category` | `uint32_t` | Offset into the world's string pool. 0 means it wears nothing. |
| `sprite_seed` | `uint32_t` | The other half of the description. |

### The category is a string in the world, not a lookup through the ruleset

The obvious alternative is to ask the ruleset at the moment the category is
wanted — it already turns a kind into a description. That was rejected, for one
reason:

**A world file must be enough on its own.** Store the category and a saved world
regenerates every picture in it with no ruleset loaded and no pool present. Store
only the kind and the same file is a set of coordinates that needs a particular
Lua file, in a particular version, to mean anything visual — and the ruleset is
the most changeable thing in the project.

The ruleset still names the category. It does it once, when a thing is furnished,
and the name is written down. Asking at generation time and remembering is the
same trade as the graph existing before the geometry: decide early, record the
decision, and stop depending on the decider.

### Two goblins are two goblins

Two things of the same kind with different seeds wear different pictures. That is
the whole point of a generated appearance layer and it is not achievable while a
kind is all a thing has.

### The world file gains a version

Two new fields per thing means version 3, a rung on the converter ladder, and the
fields folded into the world hash. A version 2 file loads with both fields zero,
which reads as "wears nothing" — the same index-0-is-nothing convention as
everywhere else, so no new rule is introduced.

### `VERB_RETIER` becomes possible

With the category and the seed on the thing, the command needs nothing else: the
subject names the thing, the thing names the sprite, the pool is attached to the
session, and the rater is the viewer who sent it.

It changes nothing in the world, which is what makes it safe to run mid-turn --
and it still runs the whole gauntlet, because the question of who may re-tier is
a permission question like any other.

**Who may, for now: whoever may edit the world.** The narrow answer, matching
`VERB_GIVE_SCOPE`. Open question 10.2 is where the wider ones live -- a shared
library that any of six people can re-tier mid-session without discussion is a
different social object from one the GM curates, and widening this later breaks
nothing while narrowing it later would.

## Suggested implementation steps

1. Add the two fields to the thing record, keeping the four-byte packing.
2. Bump the world file version, write and read the fields, add the converter
   rung, and fold them into the world hash.
3. Give the simulation a borrowed pointer to the sprite pool, the way the
   session borrows a ruleset.
4. Add `VERB_RETIER` to the verb table with its own gate.
5. Have the furnishing stage write a category and a seed onto what it places.
6. Test: two things of one kind wear different pictures; a version 2 file still
   loads; a re-tier from a live session lands in the pool and the world hash
   does not move.
