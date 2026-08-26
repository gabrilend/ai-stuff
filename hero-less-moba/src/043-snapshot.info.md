# 043-snapshot

The viewer's frame: a flat, read-only copy of everything the screen needs.

## What it is for

Stamped at the end of every tick. **Not the whole world** — the viewer has no use for
cooldown timers, target generations, or pending damage, and handing it those would
invite it to start reasoning about them. That is the first step toward a viewer that
decides something, and a viewer that decides something has taken a job away from the
simulation and put it somewhere no test is looking.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Allocates both frames. Called once at assembly. |
| `stamp(world)` | | — Copies the world into the older frame and makes it the newer. |
| `newest(world)` | | The frame just stamped. |
| `previous(world)` | | The one before it. |

## Two frames, and never a third

The viewer keeps the two most recent frames and interpolates positions between them by
the fraction of a tick elapsed. **Allowed to be behind. Never allowed to be ahead.** A
viewer that extrapolates shows things that did not happen, and in a game where a player
judges a lane by looking at where the frontline is, that is a lie that changes
decisions.

## Indexed by soldier id, not packed

The arrays are indexed by soldier id rather than compacted into a dense list. That
wastes a little space and buys the thing interpolation needs: matching a body in this
frame to the same body in the previous one is **reading the same index twice**, with no
search and no identity map. A packed frame would have to be joined against the previous
one every frame, and a body that moved slots between them would be drawn as a teleport.

`live` and `live_count` give the renderer a dense list to walk, so it never scans slots.

## What a frame holds

**Per body**: `alive`, `x`, `y`, `facing`, `team`, `flavour`, `archetype`, `reach`,
`lane`, `milestone`, `health_fraction`, `spawned_lane`, and `upgrade_count[kind][id]`.

**Per structure**: `team`, `kind`, `lane`, `alive`, `x`, `y`, `health_fraction`,
`command_radius`, `guard_count`, `upgrade_count`.

**Per team**: `chest`, `lane_slot`, `tower_slot`, `library_slot`, `push_depth`,
`waves_lost`, `draws_taken`.

**Plus**: `tick`, `phase`, `winner`, and the events raised this tick.

Health is a **fraction** rather than a figure, because the viewer draws a bar and never
a number — and because the figure would tempt somebody to compare two of them across
teams as though that meant something.

`spawned_lane` equals `lane` today. It stops being equal during a challenge, when all
three lanes' soldiers fight in the centre carrying their own lane's upgrades, and
without it that ruling is invisible and unexplainable.

## The prototype's one deliberate leak

Both teams' boards are copied in, because this prototype runs both sides on one
machine. **On a real match only the viewing player's team may be filled in** — the
enemy's chest is not on the machine at all, and their soldiers on the ground are the
whole of what you learn about their arrangement.

There is no fog-of-war system to build. There is only something not to accidentally
reveal: no enemy slot contents, no enemy transits, no enemy chest, no enemy sign-post
directions.

## Why frames are overwritten rather than rebuilt

A match that allocated two frames' worth of arrays every tick would spend more time in
the collector than in the simulation. The live list is truncated rather than cleared,
so a busy tick after a quiet one does not have to grow it again.
