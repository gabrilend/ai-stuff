# Randomness Comes From Named Streams

There is no global random number generator in this project and nothing ever
takes a number from the clock. Randomness comes from a small set of **named
streams**, each one a seeded generator that advances only when its own part of
the program asks it to.

## Why they are separate

If every random call came out of one stream, then changing how a creature
decides where to look while idling would shift every later draw — the terrace
positions, the maze's carving order, which two fencers pair off — and two runs
of the "same" seed would agree about nothing.

That is not a theoretical annoyance. It is the difference between "here is a
seed, the ball gets stuck on layer four" being a bug report anybody can
reproduce, and it being a story about something that happened once.

With separate streams, the sequence a given system draws from a given seed is
stable no matter what else in the project is edited, added, or removed. A change
to the idle animations cannot move the maze.

## The streams

| Stream | How many | Draws for |
| --- | --- | --- |
| `terrace` | one | where the slabs land and how big they are |
| `carve` | one | the order the depth-first walk tries its neighbours |
| `braid` | one | which closed links get reopened into loops |
| `stair` | one | which pair of rooms a staircase joins |
| `spawn` | one | where a body enters the aquarium |
| `wander` | one per creature kind | which way a body decides to go next |
| `idle` | one | which idle animation, and how long it runs |
| `meeting` | one | what two bodies do when they notice each other |
| `duel` | one | the exchange in a fight |
| `camera` | one | which body the camera swaps to when it is done watching |

`camera` is on this list and it does not belong to the simulation. That is
deliberate and it is the one rule about streams that is easy to get wrong: **the
camera's stream must exist, and the simulation must never read it.** A viewer
that drew from a simulation stream would make the simulation depend on whether
anybody was watching, and two runs of one seed would diverge based on whether
somebody pressed a key. Giving the camera its own stream makes that mistake
impossible to make by accident rather than merely discouraged.

`wander` is per creature kind for the same reason `terrace` and `carve` are
separate. A pack of dinosaurs and a crowd of little guys drawing from one stream
means each one's route depends on how many of the other there happened to be.

## The generator

xorshift32, through LuaJIT's `bit` library: a 32-bit state, three shifts, three
exclusive-ors, and the state is the output.

It is **not** cryptographic and does not need to be. What is asked of it is that
it be the same every time, which is a much weaker property than being
unpredictable, and the two are constantly confused. An attacker predicting where
the next dinosaur will wander is not a threat model.

Two details that are not knobs:

- The shift triple **13, 17, 5** is Marsaglia's. Changing any of the three turns
  this into a generator with a dramatically shorter period, silently.
- **Zero is xorshift's fixed point** and produces zeros forever. It is reachable
  only if a seed happens to equal a stream name's hash, which is rare and would
  be utterly baffling to debug, so it is redirected to a constant rather than
  left as a trap.

Each stream carries its `name`, its `state`, and a `count` of how many times it
has advanced. The count is not used by anything. It is there because it is
occasionally the fastest way to find out which system is burning luck it should
not be — a count that climbs while nothing is happening is a system drawing in
its idle path.

## Related documents and tools

- [Carving the maze](003-carving-the-maze.md) — the four streams the generator uses
- [The camera and what it watches](008-the-camera-and-what-it-watches.md) — the one that must stay outside
