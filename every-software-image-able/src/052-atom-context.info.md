# 052, 053 — what the machine is thinking with — info

The atom context: issue `105`, and the mechanism described in `docs/013`.

## Running the checks

```
luajit src/053-test-context.lua
```

## The rule

**The context is a concatenation of atomic artifacts and nothing else.** No
preamble, no hidden frame, nothing outside the list — so everything the machine
is thinking with can be enumerated, named and pointed at, including the
instruction it woke up holding.

That is tested rather than asserted: the whole context is rebuilt from its
enumerated atoms and must come out identical.

Joined with nothing between, since 2026-08-02. The first version put a
newline between atoms — exactly the "separator nobody named" the rule
forbids — and the thinking loop (`061`) caught it: those bytes belonged to
no atom, drifted the token accounting from the real encoding, and broke the
cache's prefix reuse at every atom boundary. An atom that wants a boundary
owns the boundary in its content.

## What it exports

| Name | Meaning |
|---|---|
| `new(options)` | a fresh context with a token budget |
| `boot(context, atoms)` | the default initialising set |
| `add`, `drop`, `carry_forward` | the resident set, chosen |
| `merge(a, b, topic)` | two atoms become one, recording both |
| `replace(number, changes)` | atoms are mutable; the number survives |
| `concatenate` | what is actually being thought with |
| `enumerate` | what is resident, so the machine can ask rather than remember |
| `find(topic)` | the index, resident or not |
| `room_left`, `make_room` | running low as a condition rather than a wall |

## Four decisions worth keeping

**A dropped atom is gone, and leaves no record.** This reverses what this file
said until 2026-08-08, which was that a dropped atom stays findable — written
when there was no storage, so "findable" meant an index entry pointing at
nothing. Now that there is somewhere to put things, the two acts are separated:
**write out** preserves and stops carrying, **drop** does not preserve. Choosing
between them is a judgement about worth, made separately from the judgement
about relevance. The accepted cost is a machine that drops something, later
wants it, and never learns it once had it; the rejected alternative was an index
filling with markers for things nobody can retrieve. `docs/013`.

**A merged-away atom's number is never reused.** Anything referring to it would
otherwise point at a different subject, which is worse than pointing at
nothing. This is the answer to the fourth open question in `docs/013`.

**An edited atom keeps its number.** Whatever referred to it meant the subject
rather than the wording.

**A split atom's number is retired, and both parts get new ones.** The same rule
as merge, run backwards, and for the same reason: afterwards the parent's subject
is two subjects, so nothing may still resolve to it as one. The parent is
recorded as what the parts came from.

## Dropping for want of room is a fallback

It is what happens when the machine did not choose in time, so it is announced
and counted, and it never takes the atoms carried on the chip — those include
the instruction and the explanation of this mechanism. When everything left is
undroppable, nothing is dropped and the room left says zero, rather than a
machine believing it made room and overrunning.

**What "in time" means was decided on 2026-08-08, and is not built here yet.**
The machine sweeps its own resident set at 80% of the manageable budget and
compacts to 60%, or as low as 40%. `make_room` as written is the crude version of
that — oldest-first, no judgement, no summarising, no splitting — and it stays as
the floor beneath the real one. The design is in `docs/013`, the thresholds are in
`docs/balance-updates.md`, and the work is `304`, reopened.

Two things this module will need for it: **room-left has to report two numbers**,
manageable and furniture, because the percentages are taken over the droppable set
alone; and **the sweep must be ordered by position, not by how bad an atom is**,
because the cache is a prefix and the replay cost is set by the earliest atom
touched rather than by how many are touched.

## The uncomfortable property, tested

A machine can edit its own prohibitions, because they are atoms in a mutable
list. Nothing prevents it. That follows from everything about the machine being
mutable, it is deliberate, and it is tested so that nobody later builds on the
assumption that it is untrue.

## The seam left open

Writing an atom out to storage and recalling it. Storage does not exist in this
phase, so a dropped atom is gone. Issue `304` closes it.

## Result on 2026-08-02

17 of 17.
