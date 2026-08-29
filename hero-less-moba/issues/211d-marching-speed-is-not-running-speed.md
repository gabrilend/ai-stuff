# 211d — Marching Speed Is Not Running Speed

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 211c |
| Blocks | 212 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

**Half built.** A body in a formation is in a **gear** rather than on a dial:
walking at seven tenths of its pace when it has got ahead of its place, marching at
its pace otherwise. Nothing exceeds marching.

A dead band of a couple of paces keeps it from switching every tick, and the width of
that band trades the tidiness of the line against how often a body changes gear. Both
numbers are printed by the formation sandbox every run — see the balance ledger for
the table they were picked from.

**The front waits** when the formation has fallen more than half a rank behind its
anchor. That is what replaced hurrying: a body on the outside of a bend has further to
walk and cannot make it up by going faster, so the front stops asking for it.

**Running is not built.** There is one speed in the catalogue and the third gear has
no number and no caller. It belongs to a body that has been beaten and is getting out,
which is [issue 212](212-a-beaten-body-gets-one-roll.md), and it should be a second
number on the archetype row rather than a multiple of the first.

## Intended behavior

**A body has two speeds.** *Settled; see
[open questions](../docs/020-open-questions.md), H7.*

| | |
| --- | --- |
| marching speed | what it does almost everything at |
| running speed | what it does one thing at |

They are two numbers about a body, in the catalogue, like reach and armour. Not a
modifier applied to one number — two facts.

### Nobody runs when chasing a kill

Closing on an enemy is done at **marching pace**. A game where bodies sprint at
whatever they want to hit turns every engagement into a scramble, and the scramble
destroys exactly the thing the formation work exists to produce: two lines meeting
as lines.

### Running is for leaving

The only thing that runs is a body that has been beaten and is getting out. That is
[issue 212](212-a-beaten-body-gets-one-roll.md), and it is the only caller.

### And the clamps have to open

[211c](211c-a-formation-is-a-circle-that-faces.md) makes a formation an oriented
disc that turns. When it turns, a body's intended place swings away from where it
is standing — outward on one side of the turn, inward on the other — and both have
to move to catch it.

The current ceiling and floor were sized for a block that never rotated, where the
only thing pulling a body off its place was fighting and dying. They are too tight
for a formation that turns, and the symptom is a line that bends through every
change of direction instead of pivoting.

So the budget's clamps open, and the thing that stops them opening into a sprint is
that **marching speed and running speed are different numbers**: a body correcting
hard inside a formation is still marching, however hard it corrects, and the ceiling
is a fraction of the march rather than a fraction of the run.

## Suggested implementation steps

1. Add a running speed to the archetype rows in the unit catalogue, and a second
   per-body field beside the existing one. Copied at birth like everything else — the
   swing path must not chase a pointer to find out how fast something is.
2. Rename the existing field so nothing can read "speed" and get the wrong one by
   accident. A body with two speeds and one of them called `speed` is a body whose
   second speed is never used.
3. Open the cohesion clamps and let the sandbox say by how much: a formation turning
   through a right angle should pivot rather than bend, and the number to watch is
   the worst the line bends during the turn.
4. Leave every existing caller on marching speed. The only new reader is issue 212.
5. Test that nothing runs except a body that is leaving — the check is that running
   speed is read in exactly one place.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [212 — a beaten body gets one roll](212-a-beaten-body-gets-one-roll.md), the only
  thing that ever runs
- The formation sandbox, which is where the clamps get sized
