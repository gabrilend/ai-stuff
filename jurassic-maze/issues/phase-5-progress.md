# Phase 5 — The Fencing

**All four issues complete.** Two sides of little guys with swords meet in the
corridors, fight, and the fights end — four different ways, all of them counted.

| Issue | |
| --- | --- |
| [501](completed/501-a-duel-is-a-record-not-two-flags.md) | a duel is a record, not two flags |
| [502](completed/502-damage-is-buffered-then-applied.md) | damage is buffered, then applied |
| [503](completed/503-a-duel-has-to-end.md) | a duel has to end |
| [504](completed/504-teams-and-what-the-camera-does-with-them.md) | teams, and what the camera does with them |

`./run-maze --scene war` runs it. `--scene fencers` is fencers alone.

## The journey, and what it taught

### The buffering was decorative until both of them struck

`502` is the issue about buffering damage so that two fencers who kill each other
in one tick both die rather than the outcome being decided by an array index. It
was implemented, correctly, and it could never have fired: the exchange took
turns, so only one blow existed per tick and a mutual kill was not reachable.

Both of them striking made the buffering load-bearing — and about one duel in
eight now ends with both of them falling.

**What it taught:** a safeguard against a case that cannot arise is not a
safeguard, it is a comment. The test that forces the case is what turned it into
one, and writing that test is what surfaced the problem.

### Two rules that exist for reasons in a different file

The **stalemate clock** is a rule about combat and its reason is about cameras:
two well-matched fencers with a high parry stand in a corridor exchanging misses
forever, and a camera watching them under "swap on its own" has nothing to swap
to, because the duel never ends so the verdict never fires.

**"Stay with the loser"** needed its meaning pinned down before it could be
written. Damage taken is accumulated on the duel rather than derived from health
afterwards, because after a stalemate both walk away and the record of who lost
goes with it. And when the loser *died* there is nobody to stay with — the camera
moves whatever the setting says, which is not a compromise but what the words
mean once one of the two is not there.

**What it taught:** both of these were phrased in the vision as things about
watching, and both turned into rules about fighting. The camera is not a
read-only observer of the design; it makes demands on it.

### Magenta

The fencer was added to the creature table and not to the palette, and it came
out magenta — which is exactly what the palette's rule for an unnamed creature is
for. A colour nobody chose is the fastest way to see that something has been
added in one place and not the other.

**What it taught:** the loud default cost one line to write in phase two and
found its first bug in phase five, from across the room, in under a second.

## Open question 1, which this phase was supposed to settle — and did, later

**Answered: the fencers.** A released fencer re-engages immediately and the fight
rolls on; `disengage_seconds` is zero. The sentence was:

> *"for the fencing guys, they should be able to swap to a different target (same
> team or no? toggle checkmark) to continue the watching experience"*

Both readings are built and both are one number:

- **`disengage_seconds` above zero** — a released fencer keeps away for a moment,
  the duel is over, and the camera goes and finds somebody else. A series of
  duels.
- **`disengage_seconds` at zero** — a released fencer re-engages immediately and
  the fight rolls on. A melee, and the camera never has to move.

`tests/061-duels.lua` asserts both behaviours, and the default is the first.

The phase was finished with the question open and the number left at four
seconds, on the grounds that which one is the default is a decision about what
the thing *is* and not one to make by leaving a number where it happened to land.
It was asked and it went the other way, and changing it was one line and one
test.

## What is worth carrying into phase 6

- A duel is the second record referencing two bodies by id and generation and
  holding a clock; the shared idle was the first. Phase six's games are the
  third, and three is when generalising is worth doing rather than guessing.
- Bodies now die. Everything that stores a body id has to be checked against a
  generation, and everything already is — but phase six adds hiding, which stores
  the id of the thing being hidden from.
