# 002 — Datapath: The Interpreter and Its Door

The lowest thing the machine builds, and the layer that quietly performs every
job a kernel would have performed.

This document describes something the machine **writes**, not something the
image ships. The image contains no interpreter. What it contains is a model, and
the engine that runs it (`010`), and the model writes an interpreter in assembly
at first boot once it knows what processor it woke up on (`003`).

**It should be among the first things built** — early enough that the storage
driver needed for moving in can be written as bytecode rather than as more
assembly. The first operations worth having are the basic hardware ones: moving
values between registers and memory locations, and the arithmetic underneath
everything else. Every further piece of software the machine writes is cheaper
once these exist, which is the argument for building it before there is anywhere
to save it.

## What it is

A program is stored as a list of plain numbers. A loop picks up the next number,
looks it up in a table, runs the matching operation, and goes back for the next
one. Forever. That number is called an **operation code**, and a table like that
is the most literal possible dispatch table: nothing is decided by asking a chain
of questions, everything is decided by using a number as an index.

```
   ┌─ fetch the next number ─────────┐
   │                                 │
   │   spend one from the countdown  │  ← the timer interrupt, in software
   │   if the countdown hit a mark, hand control to whoever is watching
   │                                 │
   │   look the number up in the operation table
   │   run that operation            │
   │                                 │
   └─────────────────────────────────┘
```

## The three kernel jobs, done here

**Taking control back.** The countdown is spent inside the fetch, one per
instruction. A program cannot avoid it, cannot disable it, and cannot write a
loop that outruns it, because the spending happens one layer below anything a
program is able to express. This is the same trick Erlang uses to keep thousands
of processes fair without a timer chip, and it is why this machine can survive a
program that never finishes without owning any hardware built for the purpose.

The alternative — having the compiler insert a countdown at the top of every
loop it emits — requires trusting that the compiler always did so. Doing it in
the fetch requires trusting nothing.

**Keeping programs out of each other's memory.** An address in bytecode is not a
machine address. It is an index the loop resolves, and resolving it is where a
comparison against the arena's bounds costs almost nothing because the loop is
already holding both numbers. There is no hardware fault to catch, so there is
nothing to catch it with; instead the case simply never arises.

**The door.** The operation table *is* the list of things a program may ask the
machine for. On an ordinary computer that list is a few hundred numbered
requests reached through a special instruction that changes the processor's
privilege level. Here there is no privilege level, and the list is simply the
table — which means the door and the catalogue of what exists are one object. A
program that wants to know what this machine can do reads the same table the
loop reads.

## The data

**Operation** — one row of the table.

| Field | Type | Meaning |
|---|---|---|
| `code` | integer | the number that selects this row |
| `name` | string | what it is called, for people and for search |
| `arity` | integer | how many numbers follow it in the program |
| `cost` | integer | how much countdown it spends; not always one |
| `aspect` | integer | which colour this operation's failures report under (`006`) |
| `added_at` | integer | which build of the machine introduced it |

`cost` is not always one because some operations are not one thing. An operation
that copies a region spends in proportion to the region, or a program can hide an
unbounded amount of work inside a single fetch and escape the countdown after
all.

**Arena** — one program's memory.

| Field | Type | Meaning |
|---|---|---|
| `arena_id` | integer | which arena |
| `base` | integer | where it begins, in machine addresses |
| `length` | integer | how many bytes it runs for |
| `shared` | boolean | whether other programs may name it |

Every program is given as much private space as it asks for, and may take part in
as much shared space as it asks for. The private/shared split is the whole of the
memory model; there is no third category and no permission list.

## The instruction set is not fixed, and is not the same twice

The machine writes its own interpreter against the processor it found. Two
machines with different processors will not agree on their operation tables,
because the operations worth having depend on what the hardware underneath does
cheaply. A machine whose processor multiplies quickly and divides slowly should
not have the same table as one where that is reversed.

This is the first place where two of these machines stop being comparable, and it
happens in the first minute. Everything downstream inherits it.

## The pull against condensation

Every new capability is a new row in the table, and the table is read on every
single fetch. A table that grows without limit makes the hottest loop in the
machine colder.

Rung four (`005`) pushes the other way — merge things that overlap, so the table
gets shorter rather than longer. The two forces meet exactly here, and the
resolution is not written yet. It is question 9 in `008`.

## Open questions

- **What decides an operation is worth a row?** Any sequence used often enough
  could become one. Never promoting anything leaves the machine slow; promoting
  freely makes the table enormous. Nothing measures this yet.
- **Where does the countdown's mark live?** `006` says a magnitude far enough
  from fifty stops the machine and starts a backward walk. Whether the
  interpreter checks against one mark or several on the way out, and whether the
  marks are per-program or per-machine, is undecided.
- **Can a program add an operation?** If yes, the door widens from inside and the
  machine can extend itself while running. If no, adding one means rebuilding the
  interpreter, which means the machine cannot learn a new trick without stopping.
