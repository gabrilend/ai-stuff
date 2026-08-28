# 042-the-tick

The heartbeat, and the assembly point where every module meets its neighbours.

## What it is for

The tick is an **ordered array of system functions**, each taking the world, rather
than a hand-written sequence of calls. Adding a system means adding a row; reordering
means moving a row. **The order of the simulation becomes readable data** instead of
something buried in a function body — which matters more than it looks, because almost
every subtle bug in a simulation like this one is an ordering bug, and an ordering bug
is much easier to find when the order is a list you can read.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load_cast(root)` | project root | Every module, keyed by the name it is hung on the world under. |
| `assemble(modules, parameters)` | | A world with every system wired and every starting condition set. |
| `advance(world)` | | `true` if a tick ran; `false` once the match is over. |
| `system` | *(table)* | The order of the simulation. |
| `cast` | *(table)* | Module names and the files they live in. |

## The order

| # | System | Does |
| --- | --- | --- |
| 1 | clear | Zeroes both damage buffers and last tick's events. |
| 2 | think | Every bot decides what it wants and queues it. |
| 3 | record | Writes this tick's commands into the replay, if anything is recording. |
| 4 | commands | Drains the command queue. The only moment player intent changes anything. |
| 5 | spawn | Wave timers and guard replacement. Everything that adds a body. |
| 6 | index | Drops every living body into the spatial grid. |
| 7 | form | Every wave advances its anchor and shares out the cohesion budget. |
| 8 | retarget | Every soldier without a living target looks for one; then the attacker sweep. |
| 9 | move | The brain, once per living body. |
| 10 | attack | Cooldowns down; anything ready writes into the buffer. Towers too. |
| 11 | resolve | The buffer is applied; the dead are marked. |
| 12 | reap | Deaths become consequences; slots are freed. |
| 13 | measure | Push depth, recomputed from the living. |
| 14 | phase | The match clock and the game-over condition. |
| 15 | snapshot | The state is stamped for the viewer. |
| 16 | log | Once a second, the accepted state becomes a replay keyframe. |

## Four orderings that are load-bearing

**Resolve after attack, reap after resolve.** Attacks write into a buffer; resolve
applies it; reap frees slots. Freeing a slot inside the resolve pass would let a later
body in the same pass be handed a slot the pass still refers to.

**Measure after reap.** Push depth is a statement about the living, so it has to be
taken after the dead have been removed. Measured before, a lane would report a depth
held by a body that died this tick.

**Think before record, record before commands.** The bots used to be called from
inside the command pass rather than standing in the table on their own, and when the
replay log went in it recorded nothing — the recorder sat between the two and saw an
empty queue, because the thing filling the queue was inside the row after it. Which
is the whole argument for the table: a system folded into another system's function
body is a step that happens and cannot be seen happening.

And the recording is before the applying because applying empties the queue — and
because a refused command still belongs in the record. A replay holding only the
accepted commands is a replay in which nobody ever made a mistake.

**Log last.** A keyframe is a statement about a finished tick. Anywhere earlier and it
would record a world halfway through being brought up to date, which is a state no
other machine will ever be in and therefore a state nothing can usefully be compared
against.

## Push depth

**Living**, not a high-water mark, so it can go down. It creeps up as soldiers advance
and collapses when they die. Recomputed in full every tick rather than maintained,
because a maintained version that drifts would be a lie told in the one place a player
is looking.

**Guards are excluded.** A guard stands at its own tower for its whole life, so counting
it would read a team's own stone back at it as though it were a push — every lane would
report a permanent depth with nobody having advanced anywhere.

## Why this file is also the assembly point

The chest needs the world and the world needs the chest, and a direct `require` in both
directions is a loop. Each module is hung on the world under a name, once, here. One
assembly point beats a web of half-loaded modules.

Modules are loaded **by path** rather than through Lua's search path, because this
project's files are named with a leading index and a dash — `require "034-walking"` is
not a thing a reader would expect to work.
