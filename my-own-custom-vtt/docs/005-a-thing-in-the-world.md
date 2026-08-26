# A thing in the world

There is one record for everything that stands in the space. A player's
character, a goblin, a coffee cup, a door, a torch on a bracket, a tree. All the
same record.

This is the single most load-bearing decision in the data model, and it is what
makes the tavern's commander possible. When somebody controls a tavern and moves
the coffee cups around, the code that moves a coffee cup is the code that moves a
goblin, because a coffee cup *is* a thing with a position and an owning scope.
There is no prop system sitting beside the creature system, no second movement
path, and no second sight rule. See [who controls what](008-who-controls-what.md)
for why that matters.

## The record

| Field | Type | Bytes | Meaning |
| --- | --- | --- | --- |
| `x`, `y` | `int32_t` | 8 | Position, in fixed point. See below. |
| `facing` | `uint16_t` | 2 | Which way it is pointed. A full turn is 65536, so one step is about 0.0055 degrees. Wraps by overflowing, which is free and correct. |
| `radius` | `uint16_t` | 2 | How much space the body takes, same fixed-point scale. A coffee cup is small; a dragon is not. |
| `scope` | `uint32_t` | 4 | Index into the scopes array: who commands this. `0` means nobody commands it. |
| `region` | `uint32_t` | 4 | Index into the regions array: the named area it currently stands in. `0` means open ground. |
| `kind` | `uint32_t` | 4 | Index into the ruleset's catalogue of what-things-are. The server does not interpret this; it hands it to the ruleset and to the view. |
| `sheet` | `uint32_t` | 4 | Index into the ruleset's own storage for this thing's numbers. `0` means the ruleset has nothing attached, which is the normal state of a coffee cup. |
| `sight_range` | `uint32_t` | 4 | How far this body can see, fixed point. `0` means it does not see, which is also the normal state of a coffee cup. |
| `sight_arc` | `uint16_t` | 2 | How wide its cone of vision is, in the same units as `facing`. A value of 32768 is a half-turn -- everything in front. |
| `flags` | `uint16_t` | 2 | The bits below. |

Thirty-six bytes, packed with no padding -- the four-byte fields are laid out
first and the two-byte fields after them, so the compiler has no hole to leave.
That is asserted by a test rather than hoped for, because the world file writes
fields one at a time precisely so that padding never reaches the disk, and a
record that silently grows a hole should fail a build rather than a load.

### The flag bits

The first two are **shared with the wall record** -- the same bit means the same
thing on a body as it does on a segment, defined once and used by both. An
earlier draft of these documents numbered them differently in the two places,
which would have produced a curtain you cannot walk through and a wall you can
see past, with nothing obviously wrong in either file.

| Bit | Name | Meaning when set |
| --- | --- | --- |
| 0 | `BLOCKS_SIGHT` | Sight does not pass through it. |
| 1 | `BLOCKS_MOVEMENT` | Bodies cannot walk through it. A wall of crates; a closed door. |
| 2 | `THING_HIDDEN` | It is never sent to anyone who does not command it, regardless of sight. The GM's ambush, standing in plain view of a corridor nobody has walked down. |
| 3 | `THING_EMITS_LIGHT` | It has an entry in the lights array. |
| 4 | `THING_MOBILE` | It is expected to move. A hint for the motion pass, not a permission. |

The two blocking bits are separate because the interesting cases are the ones
where they disagree. A chasm blocks movement and not sight. A curtain blocks
sight and not movement. A portcullis blocks movement and lets sight through. One
"solid" flag would delete all three.

## The simulation counts metres; the picture speaks feet

Two units, and the boundary between them is exactly the boundary between the
server and the view.

**The simulation stores metres.** A position is an `int32_t` counting in units of
1/1024 of a metre, which gives a range of about ±2,100 kilometres and a precision
of about a millimetre. Every distance, every radius, every wall endpoint, every
sight range in the entire server is in these units, and nothing in the server has
ever heard of a foot.

**The view displays feet, rounded to the nearest foot.** The renderer converts on
its way to the screen. Distance readouts, grid lines if a ruleset draws any, and
anything a person reads off the interface are whole feet.

That rounding is lossy and it is supposed to be. A person at a table wants to be
told "thirty feet", not "9.144 metres" and not "29.9 feet". The conversion happens
once, at the last possible moment, in the only program whose job is presentation.

The thing to hold on to: **the rounding lives in the view and only in the view.**
The moment a rounded foot travels back into the simulation -- a command that says
"move thirty feet" and gets converted to metres by the client -- two clients that
round differently will disagree about where a body went. Commands carry metres.
The view converts for the eye and never for the wire.

## Why fixed point and not floating point

The reason is not range or precision. It is that **the tick must be
deterministic**, because a replay that does not reproduce the session is not a
replay. IEEE floating point is deterministic in principle, but a compiler is
permitted to reassociate `(a + b) + c` into `a + (b + c)`, and to fuse a multiply
and an add into one instruction that rounds once instead of twice. Both change
the last bit. Do that across a machine that has fused multiply-add and one that
does not, or across two optimisation levels, and two replays of the same session
diverge -- slowly, and then all at once, an hour in, with no way to find where.

Integer addition has none of that freedom. The compiler may reorder it, and the
answer is the same. This is worth more than the convenience of writing `1.5`.

Division is the place to be careful: integer division truncates toward zero,
which is asymmetric about the origin, so a body drifting left and a body drifting
right round differently. Everywhere a divide appears in the motion path it is
written to round consistently, and the reason is written in a comment beside it,
because it is exactly the kind of thing somebody simplifies later.

## What is *not* in the record

**No name, no colour, no sprite.** Appearance lives in the ruleset's catalogue,
indexed by `kind`, and is sent to the view separately. The server can run a whole
session without knowing that the thing at `kind = 7` is called a goblin.

**No hit points, no stats, no conditions.** Those are the ruleset's, reached
through `sheet`. The server never reads them. A system-agnostic tabletop that
knew what a hit point was would not be system-agnostic.

**No pointer to anything.** Every reference is an index. See
[the world and its tick](004-the-world-and-its-tick.md) for why.

## Read next

- [The map is geometry, not a picture](006-the-map-is-geometry-not-a-picture.md)
  -- the walls these bodies move among.
- [Sight and what it remembers](007-sight-and-what-it-remembers.md) -- what
  `sight_range`, `sight_arc`, and `facing` are for.
