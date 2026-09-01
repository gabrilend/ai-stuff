# Phase 7 — The Delve

**Six of seven issues complete.**
[707 — a monster is a lock](completed/707-a-monster-is-a-lock.md) is **in progress** and is
the capstone: the machinery it needs is all built and working, and the part that
makes this a mode rather than an aquarium is not.

| Issue | |
| --- | --- |
| [701](completed/701-a-mode-is-which-tables-are-loaded.md) | a mode is which tables are loaded |
| [702](completed/702-riding-is-a-derived-position.md) | riding is a derived position |
| [703](completed/703-fire-is-a-state-that-spreads.md) | fire is a state that spreads |
| [704](completed/704-a-golem-changes-the-stone.md) | a golem changes the stone |
| [705](completed/705-vines-creep-along-walls.md) | vines creep along walls |
| [706](completed/706-the-automaton-solves-itself.md) | the automaton solves itself |
| [707](completed/707-a-monster-is-a-lock.md) | **in progress** — a monster is a lock |

`./run-maze --scene delve` runs what exists.

## The question that decided the phase, and its answer

Open question 3 — *does "solve" mean solve?* — was asked with six of seven issues
built and the seventh deliberately left alone, because it was the one the answer
decided.

**It was meant loosely.** The monsters are enemies with health, the party fights
them, and the cycle between the three of them is a damage-type chart rather than
the point of the mode.

What is striking is how little had to change. The three monsters, their
locomotion, the fire model, the entangling, the wall-breaking and the automaton
catching fire from its own work were all built for the *other* reading, and every
one of them stayed — because none of them was ever about who was fighting whom.
What was thrown away was a set of rules saying which monster undoes which, and it
was replaced by a table of nine numbers.

The fighting is [the fencing](../docs/017-fencing.md), generalised beyond
fencers. That took an afternoon rather than a phase because the duel machinery
already existed, already buffered its damage, already ended four ways and already
had tests.

## What works

The party fights and dies. Humans carry fire, dinosaurs carry weight and strike
two cells away, and neither alone is an answer to all three monsters. Vines hold
delvers still; golems walk through walls at about forty blocks a minute with the
maze opening up behind them; automatons set alight whatever flammable thing is
beside them, on any side, including the vines they are standing in.

## The journey, and what it taught

### The automaton that stopped setting fire to things

Rewriting the mode as a fight put all three monsters on one side, and the
automaton's ignition was written to fire only at the *other* side. So nothing
ever lit a vine again, and a wooden machine standing in a thicket it had ignited
stopped being possible — the best behaviour in the mode, deleted by a tidy
condition that read correctly.

It does not check now. It is a machine.

**What it taught:** a rule about who is on whose side, added while thinking about
combat, quietly reached into something that had nothing to do with combat. The
counter said zero and the demo said nothing.

### Two silent overrides, one afternoon

Both of these produced a feature that simply did not happen, with no error and
nothing in any counter, and both were an ordering or a gate rather than logic.

- **The delve's passes were gated on a flag** derived from the scene's
  population. Any body placed by another route — a test, a scenario, anything
  later — got a world where fire does not burn and riders do not ride. Four
  assertions failed on it and every one looked like a bug in the thing being
  asserted. The gate was also not worth having: three sweeps of the body store is
  a few tens of microseconds a tick.
- **The delve's blanket meet rule was written after the specific pairs**, so it
  replaced them — including dinosaur meets dinosaur, which is where phase six's
  games start. Games stopped happening entirely, and the failing test was in the
  *habitat* suite, three phases away from anything that had been touched.

**What it taught:** "which tables are loaded" is a good description of a mode and
a bad description of an implementation. The moment it becomes a flag consulted at
runtime, it is a branch that can be wrong, and its wrongness looks like the
absence of a feature rather than like a fault.

### The golem's two invisible failures

It counted its work on the shared `timer` field — which is also the idle clock,
and which the riding pass writes. The idle reset it before it ever reached the
threshold, so **no golem ever broke a wall**, and the counter said zero while
every golem in the run was busy.

Then, with its own field: a three-by-three golem can never be adjacent to a wall,
because its own footprint keeps it a cell away. It swung at nothing.

**What it taught:** a shared scratch field is a shared bug waiting for two things
to want it. `timer` is now written by the idle clock, the riding clock and the
willingness clock, and the golem has `work` — but the next thing to need a clock
will make the same mistake unless it is looked for.

### The counter that had been waiting six phases

`store.version` was written in phase one, documented as "bumped when the stone
changes", and nothing bumped it until this phase. The renderer's baked mesh is
the first thing in the project to cache anything derived from the stone, and a
golem is the first thing to change it.

It cost one line in phase one and it meant the rebuild was a comparison rather
than an investigation.

**What it taught:** the same is true of the headroom check, written in phase one
against ceilings that still do not exist, and of the footprint hook in the
spatial index, written in phase three against bodies that were not wide until
phase six. Two of those three have now paid. The third has not, and it is
honestly recorded as not having.

## What phase 6 bought that this phase spent

Every one of these was a decision made for a reason in an earlier phase and used
without modification here:

- The trace cache limits, raised in phase six, meant three more locomotion rows
  cost nothing.
- The per-caller breakdown of failed searches, added in phase six, would have
  found the pass-gating flag in one run if the flag had failed a search rather
  than doing nothing at all.
- The footprint invariant test, written in phase six, covered the golem for free.
- `lumbering` and `creeping` turned out to be `Walking.advance` with different
  numbers in the creature row. **A new way of moving was a new row rather than a
  new function** — which is what the dispatch table was for, and was not
  guaranteed.
