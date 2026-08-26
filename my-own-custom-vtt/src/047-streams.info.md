# 047-streams

Randomness that comes from somewhere you named. Nothing in this project calls a
global random function.

A caller asks for a stream **by name** — `"attack"`, `"wandering-monsters"`,
`"dungeon-layout"` — and gets a generator seeded from the session seed combined
with that name.

## Why names

One generator couples every use of randomness to every other. Add a roll anywhere
and every subsequent roll everywhere shifts: a ruleset that starts checking one
extra condition changes what monsters wander, what the dungeon looked like, and
every attack for the rest of the session.

That makes a seed **useless in practice** — you could reproduce a session only if
you never changed any code, which is exactly when you least need to.

Named streams are independent. Adding a draw to one leaves the others
byte-identical, so a seed keeps meaning something across changes to the program.
A test asserts it, and a second test asserts the *order streams are created in*
does not matter either.

## The functions

| Function | In | Out | Notes |
| --- | --- | --- | --- |
| `streams_init` | registry, seed | — | |
| `stream_named` | registry, name | index, or `STREAMS_MAX` on failure | Creates it if new. The same name always gives the same stream for a given seed, forever. |
| `stream_next` | registry, index | `uint64_t` | |
| `stream_below` | registry, index, bound | value in [0, bound) | Free of modulo bias. |
| `stream_between` | registry, index, low, high | value in [low, high] | **Inclusive at both ends**, which is what a die is. |
| `streams_copy` | destination, source | — | What rollback uses. |
| `streams_hash` | registry | `uint64_t` | Folded into the world hash. |

## Rejection, not modulo

Taking a raw draw modulo a bound makes the low values very slightly more likely,
because the generator's range does not divide evenly. Invisible in one roll, and
a loaded die across ten thousand generated dungeons.

`stream_below` discards draws below a threshold instead. A test rolls 60,000 d6
and checks the faces land within a few per cent of each other.

## Everything here is frozen

The splitmix constants, the FNV name hash, all of it. Changing any of them
retires every seed anybody has written down — silently, because the new generator
produces perfectly good random numbers, just different ones.

This is also why nothing is borrowed from a library: a library's generator can
change between releases and take the meaning of every recorded seed with it.

## Refusals

An empty or over-long name is refused, and a full table is refused. Both because
the alternative is two things silently sharing one stream and starting to
interfere with nothing reporting it.

## Rollback depends on this

A stream's position is part of every snapshot. Restore the world without
restoring the dice and a retconned turn draws different numbers for a reason
nobody can see — **which looks exactly like the retcon having worked**, and is
the hardest kind of wrong to notice.
