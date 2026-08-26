# 305 -- Randomness comes from named streams

**Phase:** 3, the world ticks
**Blocked by:** [301](301-the-tick-is-a-dispatch-table.md)
**Blocks:** [307](307-the-world-hashes-itself.md),
[707](707-dice-come-from-named-streams.md), and phase 8's generators.
**Documents:** [the rules layer](../docs/011-the-rules-layer.md),
[content is generated](../docs/013-content-is-generated.md)

## Current behaviour

Nothing exists.

## Intended behaviour

Nothing in this project calls a global random function. A caller asks for a stream
**by name** -- `"attack"`, `"wandering-monsters"`, `"dungeon-layout"` -- and gets a
generator seeded from the session seed combined with that name.

### Why names, and not one stream

Because one stream couples every use of randomness to every other use.

With a single generator, adding a roll anywhere shifts every subsequent roll
everywhere. A ruleset that starts checking one extra condition changes what
monsters wander, what the dungeon looked like, and every attack for the rest of the
session. That makes a seed useless in practice: you can reproduce a session only if
you never change any code, which is exactly when you least need to reproduce it.

Named streams are independent. Adding a roll to `"attack"` leaves
`"wandering-monsters"` byte-identical. **A seed keeps meaning something across
changes to the program**, which is what makes it worth having.

### The properties required

| Property | Why |
| --- | --- |
| Deterministic from seed and name | Two machines, same result. Everything downstream rests on this. |
| Independent across names | Adding a draw in one place disturbs nothing else. |
| No global state | A stream is a value the caller holds, not a thing to be initialised. |
| Snapshottable | Rollback restores stream positions along with the world, or a replayed turn draws different numbers. |
| Integer only | No floats anywhere, for the reasons in [101](101-the-arithmetic-is-integers.md). |

The last two are the ones that get forgotten. A stream whose position is not part
of the snapshot makes [309](309-taking-a-turn-back.md) silently wrong -- the world
restores, the dice do not, and the retconned turn plays out differently for a
reason nobody can see.

### It does not need to be cryptographic

It needs to be fast, small, reproducible, and well-distributed. A small integer
generator with a good avalanche is right. **Write down the choice and why**, because
somebody will eventually propose replacing it with something from a library, and
the answer is that a library's generator can change between versions and take every
old seed's meaning with it.

## Suggested implementation steps

1. Write the seed-and-name mixing. A hash of the name combined with the session
   seed; the same name must give the same stream forever, so the name hash is
   frozen once chosen.
2. Write the generator. Integer state, integer output, plus a bounded draw that is
   free of modulo bias -- the bias is invisible in play and shows up as a loaded die
   across ten thousand generated dungeons.
3. Make a stream's state part of the world snapshot.
4. Provide the stream registry as a fixed table sized at startup rather than
   growing -- streams are named at build time by the code that uses them, and a
   ruleset asking for a name at run time gets an entry allocated once at load.
5. Write the companion `.info.md`, listing every stream name in use. That list is
   the map of where randomness enters the project.
6. Test: same seed and name gives the same sequence; different names give
   uncorrelated sequences; drawing from one stream leaves another untouched;
   snapshot and restore resumes exactly.
