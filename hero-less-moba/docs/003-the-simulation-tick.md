# 003 — The Simulation Tick

**Datapath document.** Covers the heartbeat: what happens in what order every
time the world advances, where player intent enters, where randomness comes from,
and why none of this knows whether anyone is looking at it.

## Two programs, not one

The project is split down the middle, and the split is load-bearing:

- **The generator** takes a world state and a list of player commands and
  produces the next world state. It draws nothing, reads no keyboard, opens no
  window, and has no notion of a camera. It is a pure function of (state,
  commands).
- **The viewer** takes world states and draws them. It never writes to a world
  state. It never decides anything the generator could have decided.

Keeping these apart means a bug is always on one side of the line. If a wave
pushes wrong, the viewer cannot be at fault. If a health bar is in the wrong
place, the simulation cannot be at fault. It also means the whole game can be run
a thousand times at maximum speed with no window open, which is how balance gets
tested. See [the viewing layer](017-the-viewing-layer.md).

## The tick

The world advances in fixed steps. The step length is a constant, not a measured
frame time, and every duration in the game is expressed as a whole number of
ticks rather than in seconds. A soldier's attack cooldown is "22 ticks," not
"0.7 seconds." This removes an entire family of bugs where two machines
simulating the same game drift apart because one of them had a longer frame.

The viewer runs at whatever rate the display wants and interpolates between the
two most recent world states. It is allowed to be behind. It is not allowed to
be ahead.

### Order of operations inside one tick

The tick is a **dispatch table** — an ordered array of system functions, each
taking the world — rather than a hand-written sequence of calls. Adding a system
means adding a row; reordering means moving a row; and the order becomes a piece
of readable data instead of something buried in a function body.

0. **Clear.** Both damage buffers and last tick's events are zeroed, so nothing can
   be applied twice and a viewer reading a snapshot sees exactly that tick's events.
1. **Think.** Every bot decides what it wants and queues it. Its own step rather
   than something folded into the next one, and it was the latter until the replay
   log went in and recorded nothing — the recorder sat between the two and saw an
   empty queue, because the thing filling the queue was inside the step after it.
   Which is the argument for the table: a system hidden inside another system's
   function body is a step that happens and cannot be seen happening.
2. **Record.** If anything is recording, this tick's commands are written down —
   **before** they are applied, because applying them empties the queue, and because
   a command that gets refused still belongs in the record. See issue 107.
3. **Apply commands.** Every command queued since the last tick is applied, in a
   fixed order by player number, then by arrival index. This is the only moment in
   the whole tick when player intent can change anything — and a bot's intent
   arrives the same way, through the same queue, on the same tick. See
   [players, teams, and commands](016-players-teams-and-commands.md).
4. **Spawn.** Wave timers, the surge stream, guard replacement, and the transits
   that land with a wave. Everything that adds a body to the world does it here.
5. **Index.** Every living body is dropped into the spatial grid, rebuilt whole
   rather than maintained — a grid that is updated as bodies move is a grid that is
   wrong the first time somebody forgets, and being wrong looks like soldiers
   ignoring an enemy standing next to them.
6. **Form.** Every wave advances its anchor down its lane and shares out the
   cohesion budget among the members still marching.
7. **Retarget.** Every soldier without a living target looks for one; then the
   "who is swinging at me" map is rebuilt for the next tick to read.
8. **Move.** The brain, once per living body. Junction decisions are resolved here.
9. **Attack.** Cooldowns tick down; anything ready and in range deals damage into
   a pending-damage buffer rather than straight into health. Towers shoot, and
   abilities fire — through the same buffer, on the same boundary.
10. **Resolve damage.** The buffer is applied. This two-stage split is what makes
   simultaneous kills work the same way every run — two soldiers that would kill
   each other on the same tick both die, and neither one's death cancels the
   other's blow.
11. **Reap.** Two sweeps. Bodies at zero health **leave the field and begin decaying**
   — off the grid, out of every queue, out of the living count, and still holding
   their slot. Bodies whose decay has run out become final: personal resource paid
   out, wave-completion counters decremented, tower-destroyed rewards issued, slot
   released. **A death is a two-second process**, because a death is the one thing a
   correction from another machine can never reach once the slot is gone. See issue
   210.
12. **Measure.** Push depth, recomputed from the living. **After the reap**, because
   it is a statement about who is still standing.
13. **Phase.** The match clock advances. The wallet ladder climbs, surges start and
   end, challenges begin, the game-over condition is checked.
14. **Snapshot.** The state is stamped for the viewer.
15. **Log.** If anything is recording, once a second the accepted state is written
   down as a keyframe. **Last**, because a keyframe is a statement about a finished
   tick; anywhere earlier and it would record a world halfway through being brought
   up to date, which is a state no other machine will ever be in and therefore a
   state nothing can usefully be compared against.

## Where randomness lives

Randomness is not global and is never taken from the system clock. The world
holds a small set of **named random streams**, each one a seeded generator that
advances only when its own system asks it to:

| Stream | Used for |
| --- | --- |
| `draw` | Which upgrade comes out of the chest when a wave is wiped. One stream per team. |
| `boon` | Which **two** boons each player is offered in the calm after a slain monster. |
| `deck` | The one shared upgrade sequence both teams draw from, generated once at match start. |
| `surge` | The deal order and starting lane when the chest is dealt across a surge spawn. One stream per team. Advances several times a second while a surge runs — far more than any other. |
| `wander` | Where a tower's guards choose to patrol. |
| `tie` | Breaking exact ties in target selection. **One per team, and three of them** — the monsters are their own team and break ties like anything else. |

Splitting them matters: if all randomness came from one stream, a cosmetic change
to how guards wander would silently change which upgrades a team draws, and no
two runs of the "same" match would agree. With separate streams, the draw
sequence for a given seed is stable no matter what else is edited.

The match seed is chosen once at match start and written into the replay header.

## What determinism does and does not buy

**Same machine, same binary, same seed, same commands, same result.** That holds,
and a test asserts it after every build. It is the project's most valuable
regression test: it fails the day someone introduces a global random call, an
iteration over a hash table whose order is not stable, or a dependence on
wall-clock time — immediately, rather than three weeks later.

**Different machines are not required to agree, and will not.** Positions,
health, and damage are doubles, and two processors — or the same processor with
different LuaJIT builds — can differ in the last bit. This project does not try
to prevent that. It corrects it: machines reconcile continuous state on a cycle,
with the authority rotating between players, while *choices* are broadcast
immediately and are never rolled back. See
[players, teams, and commands](016-players-teams-and-commands.md).

Two things follow, and the second one caught this documentation out:

- **No fixed-point rewrite is needed.** Every duration is still a whole number of
  ticks — that is about two machines agreeing on *when*, which they must — but
  positions and health can stay as doubles.
- **A replay is not simply a seed plus a command list.** That would be true under
  lockstep, where nothing outside the simulation ever writes into it. Under a
  rotating authority the world is periodically overwritten from another machine,
  so a replay has to record the accepted snapshots as well. Built: see issue 107.

Building that turned up two things the network design had not been asked yet, and
both are written down as questions rather than guessed at. **A position in this
simulation is not an x and a y** — those are derived on every move pass, so writing
them onto a body accomplishes nothing at all. And **a machine that killed a body the
authority did not can never be corrected**, because the slot is gone. See
[open questions](020-open-questions.md), H1 and H2.

## Where the threads go

The tick is mostly a loop over thousands of soldiers doing identical arithmetic,
which is the shape work has to have before a thread pool helps. The rule the
project follows: **memory is allocated up front, then the work of filling it is
handed out in slices**, so a worker that finishes early can take the next slice
off the pile instead of waiting on the slowest one.

- **Retarget**, **move**, and **attack** are read-only over the world and write
  only into per-soldier fields or the pending-damage buffer. These are sliced
  across the pool.
- **Resolve damage**, **reap**, and **phase** mutate shared structures and run on
  one thread. They are short.
- **Spawn** runs on one thread because it allocates ids.

The shape is a pool over shared memory, not one thread per soldier — slices taken
off a pile rather than one worker per body.

**None of this is built, and the mechanism named for it does not work.** The plan
has always said "a pool of coroutines," and coroutines in Lua all run on one
operating-system thread: they hand control to each other and never hold it at the
same time. Over a tick that is entirely arithmetic and never waiting, that is a more
complicated way to take exactly as long. Real parallelism here means separate Lua
states over FFI memory, which is a change to how the world is stored. See
[open questions](020-open-questions.md), H3.
Nothing is ever processed one-item-at-a-time on a single thread when the items
do not depend on each other.

## The world record

The world is one table of flat arrays, not an array of tables. Every soldier's
health lives in one contiguous integer array, every soldier's lane in another.
The reasons are the usual ones — the move pass touches four fields out of thirty
and should not drag the other twenty-six through the cache — plus one specific
one: slicing a flat array across a thread pool is a pair of integer bounds, and
slicing an array of tables is a pointer chase.

| Field | Type | Meaning |
| --- | --- | --- |
| `tick` | integer | Ticks elapsed since match start. The clock for everything. |
| `phase` | integer | 1 = normal, 2 = siege-surge, 3 = challenge, 4 = the calm, 5 = over. |
| `challenge_index` | integer | 1, 2, or 3 — which of the three named monsters. The third never ends. |
| `soldier` | struct-of-arrays | Every walking body: wave units, heroes, guards, monsters. |
| `structure` | struct-of-arrays | Towers and libraries. |
| `team` | array[2] of team record | Push depths, boons, deck index, waves lost. The chest itself is an array of **stones** — instances with a holder — of which the per-slot counts are a cache. |
| `player` | array[6] of player record | Commander, resource per colour, ceiling per colour, and what has been wasted. **No lock or objection state** — a stone belongs to whoever drew it, so there is nothing to lock it against. |
| `stream` | table of named generators | The random streams above. |
| `pending_damage` | double[] | One slot per soldier, cleared every tick. |
| `soldier.decaying` | integer[] | Ticks of decay remaining. Zero for everything alive and everything gone. |
| `capacity` | integer | How many soldier slots exist. Written down rather than left as the length of one of the arrays, so anything allocating a parallel array asks the world how big it is. |
| `replay` | record | The replay log. Present whether or not anything is recording — **not recording is a state, not an absence**, and its sink is the integer 0. |

Related: [a unit and what it carries](004-a-unit-and-what-it-carries.md) ·
[combat and damage](006-combat-and-damage.md) ·
[players, teams, and commands](016-players-teams-and-commands.md) ·
[the shape of the code](018-the-shape-of-the-code.md)
