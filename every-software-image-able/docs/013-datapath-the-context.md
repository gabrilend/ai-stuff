# 013 — Datapath: The Context

What the machine is thinking with, at any moment, and how it decides.

## The rule

**The context is a concatenation of atomic artifacts and nothing else.**

There is no preamble, no hidden frame, no privileged instruction sitting outside
the list. Everything the machine is currently thinking with is an atom, and the
whole of it can be enumerated, named and pointed at. Asking "what am I working
from" returns a list rather than an impression.

## What an atom is

A chunk of context grouped by topic — one subject, held together, small enough to
be carried or dropped as a unit.

| Field | Type | Meaning |
|---|---|---|
| `atom_id` | integer | which atom |
| `topic` | string | what it is about; what the index is keyed on |
| `content` | bytes | the text itself |
| `origin` | string | carried on the chip, written by the machine, or arrived on a channel |
| `resident` | boolean | whether it is in the context right now |
| `stored` | boolean | whether a copy exists on disk |
| `derived_from` | table | array of `atom_id` — what it was merged or summarised from |
| `changed_at` | integer | when it was last altered |

**Atoms are mutable.** They can be edited, merged into one, summarised into
something shorter, or transformed into a different shape entirely. `derived_from`
is what keeps that from being amnesia — an atom that came from two others says so.

## What the machine does with them

Every one of these is a tool call. None of it happens automatically, and that is
the point: what the machine is thinking with is a decision it makes rather than a
policy applied to it.

```
carry forward     keep this atom resident for the next thought
drop              stop carrying it; it is gone unless it was stored
write out         put it on disk, and stop carrying it
recall            read one back from disk and make it resident
merge             two atoms become one
summarise         one atom becomes a shorter one
transform         change it into a different shape for a different purpose
```

This replaces the question of what happens when the context fills. Nothing
overflows. The machine is choosing, continuously, what it is thinking with — and
running low is a condition it can see and act on rather than a wall it hits.

## The index

Atoms that are not resident are useless unless they can be found, so the index is
what makes the whole arrangement work rather than merely tidy. It is keyed on
topic and searched by task: *what do I have that bears on what I am doing right
now.*

This is what `005` calls cognition space — not how much the machine can hold, but
what it can reach for while holding something else.

## The system prompt is not special

It is one atom, or several. It has the same fields as everything else, it can be
dropped, and it can be edited.

There is a **default initialising context** — a file naming the atoms loaded when
the machine boots — and it is mutable. So the machine can change what it wakes up
believing.

That is consistent with everything else here (`010`: everything about the machine
is mutable), and it has a consequence worth stating plainly rather than
discovering: **the two prohibitions are atoms too.** The rule about never writing
to the registers that destroy hardware, and the rule about never modifying a mind
while it is running, are text in a file the machine is permitted to edit. Nothing
in this design prevents a machine from editing away its own brakes.

Whether that should be true is not settled here. What is settled is that it is
currently true, and that pretending otherwise would be worse.

## Where this leaves the seed

The seed carries the initial atoms — the instruction, the patterns, the device
descriptions (`301`, `302`, `303`) — as atoms rather than as one block of text,
and carries the default initialising context naming which of them are resident at
boot. Everything else is reachable through the index.

## Open questions

- **What happens if it drops the atom that explains atoms?** The instructions for
  managing context are themselves context. A machine that drops or corrupts them
  loses the ability to recover them, since recovering requires knowing how. This
  is the same shape as modifying a running mind (`010`) and may want the same
  answer.
- **What stops it thrashing?** Deciding what to carry costs thinking, and a
  machine that spends its context deciding what to keep in its context has spent
  it.
- **Who writes the first atoms the machine makes?** The seed's atoms are written
  by people. The first one the machine writes for itself is where its own
  vocabulary starts, and nothing says whether it should be shown examples or left
  to arrive at a shape.
- **Does an atom's identity survive a merge?** Two atoms merged into one leaves
  two identifiers pointing at something that no longer exists separately, and
  anything that referred to them by number now refers to a ghost.
