# datapath — the ladder

How a piece of text becomes a descent and comes back up. This is the
central datapath; every other one hangs off it.

## The unit

Everything the program handles is a **unit**. One Lua table, the same shape
at every rung, because the whole design rests on the rungs being one
mechanism at different sizes.

| Field | Type | Meaning |
|---|---|---|
| `id` | string | stable name of this unit, e.g. `"0.2.1"` — the path down the ladder to reach it |
| `rung` | number (integer) | which rung this unit lives at, 0 at the document |
| `text` | string | the bytes of this unit, exactly as they appeared |
| `from` | number (integer) | byte offset of the first byte, 1-based, into the whole original text |
| `to` | number (integer) | byte offset of the last byte, 1-based, inclusive |
| `pieces` | array of unit, or nil | what this unit split into; nil means it was never split |
| `mirror` | string, or nil | the turned-around version, once one exists |
| `angle` | number, or nil | 0.0 to 2.0, distance between unit and mirror; nil until measured |
| `by` | string, or nil | name of the door that produced the mirror; nil if mechanical |

`from` and `to` are the load-bearing fields. Every unit can point at the
exact bytes it came from, all the way down to a clause four rungs deep.
That is what makes the record verifiable — a reading can be checked against
the original text byte for byte, and a mirror can always be put back beside
precisely the thing it mirrors. Text is never copied out of its context and
then lost track of.

Offsets are **byte** offsets, not character offsets. Lua strings are byte
strings and the text will contain UTF-8; using byte offsets means
`string.sub(original, u.from, u.to) == u.text` holds exactly, with no
encoding assumptions anywhere in the program. Character positions are a
presentation concern and are computed by the viewer, which is the only part
that needs them.

## The rung

A rung is a row in a dispatch table. Not a class, not a module — a table
with four functions and a name, keyed by rung number. Adding a scale to the
ladder is adding a row.

| Field | Type | Contract |
|---|---|---|
| `name` | string | what this rung calls its pieces, e.g. `"sentences"` |
| `split` | function(unit) → array of unit | find the seams; returns `{unit}` if there is only one piece |
| `turn` | function(array of unit) → array of unit | reorder the pieces; usually reverse |
| `mirror` | function(unit, transport) → string | turn one piece around; may be mechanical, may call a door |
| `join` | function(array of unit) → string | put the pieces back into text |
| `costs` | boolean | true if `mirror` reaches a door; the scheduler needs to know |

The dispatch table is indexed by rung number, so descending is a table
lookup and not a chain of conditionals. Rungs do not call each other and do
not know their own index — the descent supplies it.

## The descent

    descend(unit, rung_number, depth_budget, transport) → unit

1. If `rung_number` exceeds the depth budget, **error**. Do not return the
   unit unfinished. A silently-floored descent produces a record that looks
   complete and is not, and nothing downstream can detect the difference.
2. Look up the rung. If there is no rung at this number, the ladder has
   ended naturally — this is the bottom, and it is fine.
3. `split` the unit into pieces. If it split into exactly one piece
   identical to itself, the seam-finder found nothing; stop here rather
   than recursing forever on the same bytes. This is the second floor, and
   it is the one that actually fires in practice.
4. Recurse into each piece. **The pieces are independent** — nothing a
   piece learns affects its siblings — which is why this is the point where
   the work fans out across doors.
5. `turn` the returned pieces to reorder them.
6. `join` the turned pieces into this unit's `mirror`.
7. If this rung's `mirror` is itself meaningful (rung 4 and below), call it
   and let it override the joined text.

Steps 5 and 7 are both present, and their interaction is the thing the
worked example in the vision showed: a sentence's mirror is its clauses
*reordered* (step 5) with each clause *inverted* (step 7 one rung down).
Neither rung knows the other is happening.

## Ascent

There is no separate ascent pass. The mirror of a whole is assembled from
the mirrors of its pieces as the recursion returns, so the climb is the
return path of the descent. The record is written on the way up, which
means a unit is only ever written after everything below it is finished and
its checksum can cover the finished subtree.

## Where the fan-out happens

Step 4 is the only parallel step, and it is embarrassingly parallel — the
pieces of a unit share nothing. The descent is therefore expressed as: push
each piece onto the task stack as a coroutine, resume them until all have
finished, then continue at step 5. A unit with 40 sentences becomes 40
coroutines that can be in flight against five doors at once.

The barrier at step 5 is real and unavoidable: a whole cannot be joined
until all its pieces are back. But it is a barrier per-unit, not
per-rung — sentence 3 of block 1 can be down at clause level while sentence
9 of block 1 has not started, and blocks do not wait for each other at all.

## Seam finding, and why it is two-stage

Rungs 0 and 1 have unambiguous seams: blank lines and newlines. They are
pure byte work and never touch a model.

Rungs 2 and 3 do not. The vision is explicit that a sentence is *"a self
contained idea that may or may not reference those it is embedded with"* —
which is not a punctuation rule. `Dr. Smith went home.` is one sentence
with two periods; `she left. he stayed.` is two. And an idea can span a
period or stop before one.

So seam-finding is two-stage:

1. **Mechanical**, always: punctuation, quotes, abbreviations, and a table
   of known exceptions. Fast, deterministic, testable, and right most of
   the time.
2. **Refined**, optionally: a door is shown the mechanical split and asked
   only whether any two adjacent pieces are really one idea, or any one
   piece is really two. It returns seam positions, never text.

Stage 2 returning *positions only* is deliberate. A model that returns text
can silently alter it, and then the byte offsets are lies and the record
cannot be verified against the original. Returning offsets means the worst
a confused model can do is split in a silly place — the text itself is
still the person's text. Any offset outside the unit's own range is
rejected and the mechanical split stands, with the disagreement recorded.

## What flows where

    input/ text
       │
       ▼
    002-text.lua ──── loads bytes, finds line seams, never modifies
       │
       ▼
    004-grain.lua ─── wraps bytes as the rung-0 unit
       │
       ▼
    008-ladder.lua ── the dispatch table of rungs; owns the descent
       │      │
       │      ├─ 006-seams.lua ......... mechanical splitting, rungs 2 and 3
       │      ├─ 010-mechanical-mirror.lua  turning that needs no model
       │      └─ 022-model-mirror.lua ... turning that does, via a transport
       │                    │
       │                    └─ 028-door-pool.lua → a door → llama.cpp
       ▼
    014-record.lua ── append-only, checksum-chained, written on the way up
       │
       ▼
    output/readings/<name>.reading
       │
       ▼   (a separate program, another day)
    036-view-terminal.lua / 037-view-html.lua

## Related

- `docs/architecture.md` — why the ladder is the shape
- `docs/datapath-the-record.md` — what gets written on the way up
- `strategems/reversal-is-scale-free.md` — the pattern in general
