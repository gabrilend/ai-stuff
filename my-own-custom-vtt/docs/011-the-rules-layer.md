# The rules layer

The server knows about space, sight, things, and permission. It does not know
what a saving throw is. Everything that is game-specific lives in a **ruleset**,
which is loaded at startup the way a font is loaded, and which can be swapped
without recompiling anything.

This is the part of the project that is a language inside a set of constraints,
which is a thing worth building carefully.

## The ruleset is Lua, embedded in the C server

LuaJIT compiles into the server as a library. A ruleset is a directory of Lua
files. It is not a plugin in the sense of a shared object -- it never gets to
execute arbitrary machine code, and it can only reach the world through the
interface below.

Why Lua and not a bespoke language: a tabletop ruleset needs tables, arithmetic,
string handling, and closures, and writing a language that has those badly is a
year of work that produces something worse than what already exists. Why not C:
because a ruleset is the part people are expected to write and rewrite, and a
segfault in somebody's homebrew should not take down the table.

Why not a data format with no code at all -- a big JSON of stats: because rules are
not data. "When this creature drops below half its hit points it flees toward the
nearest exit" is a program, and a data format that can express it has become a
programming language with an awkward syntax.

## What the ruleset can reach

A deliberately narrow interface. The ruleset **cannot**:

- write to any socket
- read another viewer's fog or sight
- change a scope's ownership
- disable a gate in the outbound filter

Those exclusions are the whole point. The security argument in
[what a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md) has
to survive a carelessly written ruleset, so the ruleset is never in a position to
break it. It can decide *what a sheet field means*; it cannot decide *whether a
socket gets bytes*.

It **can**:

| Capability | Shape |
| --- | --- |
| Read the world | Positions, facings, regions, walls. Read-only, and only through accessors that take an index. |
| Own the sheets | The storage behind every thing's `sheet` index is the ruleset's, in whatever shape it likes. The server allocates and frees; it never reads. |
| Veto commands | Gate 5 of [the gauntlet](010-commands-enter-through-one-door.md). Returns permitted, or refused-with-a-sentence. |
| Request changes | Ask the server to move a thing, flip a wall's bits, set `HIDDEN`. Requests, checked the same way a participant's are. |
| Answer questions about knowledge | Given a viewer and a thing, which sheet fields may they know. See below. |
| Describe kinds | Given a `kind` index, what the view should be told about how it looks. |
| Roll | Through named streams. See below. |

## The hooks

A dispatch table again -- a ruleset provides the entries it cares about and the
rest are the empty function.

| Hook | When | What it is for |
| --- | --- | --- |
| `on_load` | Once, at startup | Read catalogues, register kinds, set up sheet storage. |
| `on_command` | Gate 5, per command | Permit or refuse, with a reason. |
| `on_action` | Per `RULES_ACTION` | The one door every game-specific verb comes through. Casting, attacking, searching -- all of it, here. |
| `on_tick` | Pass 4, per tick | Timers, ongoing effects, anything with a duration. |
| `on_region_enter` | When a body crosses a boundary | "When they enter the tavern." |
| `on_interact` | Per `INTERACT` | Opening the door, picking up the cup. |
| `may_know` | Per viewer, per thing, in the outbound filter | Which sheet fields this viewer may be told. |
| `describe` | Per kind, once | What the view is told about appearance. |

`on_action` is where a whole game lives. Everything the server does not understand
arrives there with a scope attached, and what comes back is a refusal or a set of
requested changes.

## Determinism, which the ruleset can break and must not

The tick is deterministic and a replay depends on it. A ruleset that calls the
system clock, or reads `/dev/urandom`, or iterates a table in hash order and acts
on the first key, destroys that -- and destroys it *quietly*, so that the replay
diverges an hour in with nothing to point at.

So:

- **No wall clock.** The ruleset is given the tick number. It has no access to the
  time of day.
- **No ambient randomness.** Dice come from **named streams**: a ruleset asks for
  a stream by name -- `"attack"`, `"wandering-monsters"` -- and gets a generator
  seeded from the session seed and that name. Two streams never interfere, so
  adding a roll in one place does not shift every roll everywhere else, which is
  the failure that makes seeded randomness useless in practice.
- **No unordered iteration where it matters.** Anything that walks a set and acts
  on it walks it in index order.

A validator that runs the same session twice and compares the world hash catches
all three. It runs in the build.

## Where dice actually live

A roll is not a server concept. The server has streams and the ruleset has dice,
and "3d6+2" is a string the ruleset parses. This is right for a system-agnostic
tabletop: dice pools, exploding dice, roll-and-keep, and card draws are all the
same shape to the server, which is to say invisible.

What the server does guarantee is that a roll is **witnessed**: it happened on the
host's machine, from a stream nobody at the table controls, and it is in the
command log. Nobody can reroll a bad result by refreshing their browser, because
the roll was never on their machine.

## Read next

- [The dynamic picture](012-the-dynamic-picture.md) -- what `describe` feeds.
- [Content is generated](013-content-is-generated.md) -- the other half of what a
  ruleset directory contains.
