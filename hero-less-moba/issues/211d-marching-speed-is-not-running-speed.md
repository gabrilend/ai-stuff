# 211d — Marching Speed Is Not Running Speed

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 211c |
| Blocks | 212 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

A body has one speed, a double in paces per tick, copied into its slot from its
archetype row at birth. Everything it does, it does at that speed: marching in
formation, closing on an enemy, walking home, wandering a patrol.

The cohesion budget scales it — bodies behind their place hurry, bodies ahead give
way — but only between a ceiling of about one and a half times and a floor of about
half. Those clamps exist so that a straggler cannot appear to teleport and a leader
cannot stop dead.

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
