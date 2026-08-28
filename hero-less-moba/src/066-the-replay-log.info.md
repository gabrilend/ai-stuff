# 066-the-replay-log

Records a match as it is played, and plays one back.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

A replay of a match in this project is **not** the seed plus the list of commands.
That would be enough under lockstep, where nothing outside the simulation ever
writes into it, and the file would be a few hundred bytes.

This project is not lockstep. Machines reconcile continuous state on a cycle with
the authority rotating between players, so the world is periodically overwritten
from outside. Replaying commands against a seed then reproduces *a* match rather
than *the* match — the same opening, diverging quietly, ending somewhere else.

So a replay carries three streams:

| Stream | Rate | Weight |
| --- | --- | --- |
| The header | once | tiny |
| Commands | a few a second across six players | small |
| Keyframes | one a second | **almost the whole file** |

The keyframes are the expensive stream and they are the honest one. Everything
else is an argument that the match *could* have gone this way; the keyframes are
the record that it *did*.

Measured: about two hundred seconds of a two-bot match comes to roughly 1.3 MB, or
about 6.5 KB per second of play. Run the recorder yourself if you need a current
number — `./run-prototype record <path>` prints the size it wrote.

## The three things this file got wrong first, and what they taught

Worth reading before changing anything here, because each one looked correct while
doing nothing.

**A position in this simulation is not an x and a y.** A body walking a lane is
stored as how far along the lane and how far across it; x and y are derived from
those on every move pass. The first version of the correction wrote x and y, the
next move pass recomputed them, and every counter reported success. What goes into
a keyframe is the authoritative set — lane, along, across, path index, the edge a
body is on, and how far into it — with x and y carried alongside purely so a person
reading the file can picture where a body was.

**Which lane a body is in is a decision, not a drifting number.** It is taken once
at a junction. Two runs that disagree about it have not drifted apart, they have
taken different turns, and writing the record's lane onto the body produces a body
standing in a lane it never entered with a path index into a path it is not on.
That crashes the walk, which is how it was found. A body whose lane disagrees is
now counted as unreconcilable and left alone. See
[open questions](../docs/020-open-questions.md), H1.

**The bots must not think during a playback.** Their decisions are already in the
record, so letting them decide again applies every one twice and the match diverges
within a couple of minutes while every part of the machinery looks correct. The
general form of the rule: during a playback the command stream is the only thing
allowed to want anything.

## The hash, and what it is not

Every keyframe carries one integer summarising the whole world, so a failure can
say **which tick** diverged rather than merely that one did.

It is taken over quantised positions — sixty-fourths of a world unit, far finer
than a body's own radius — because two machines running the same match differ in
the last bit of a double, and a hash of raw doubles would disagree everywhere and
mean nothing.

The cost is a cliff: two positions a hair apart on either side of a sixty-fourth
hash differently. So it answers "are we the same" with a usable no and an
approximate yes, and **nothing is ever halted because of it**. When you want to
know *how far* apart, use the distance from `compare_keyframe` instead — half a
world unit is two machines rounding differently and forty is a different match.

## The format is text, on purpose

One record per line, first word says which kind. It is several times the size of a
packed binary encoding and that is the price paid for a file that greps, diffs, and
can be read by a person hunting for the tick where something went wrong. This
project already keeps two viewers for the same reason — a second consumer keeps the
first honest — and a replay you cannot read is a replay you have to trust.

| Record | Fields |
| --- | --- |
| `replay` | format number; a file from another format is refused, not migrated |
| `seed` | the match seed |
| `rules` | the rules stamp, below |
| `keyframe_every` | ticks between keyframes |
| `team_size`, `opening_tick` | |
| `player` | number, commander, team — one per player |
| `header_end` | |
| `command` | tick, player, verb, then `name=value` arguments in sorted order |
| `frame` | tick, hash, phase, challenge index, how many change lines follow |
| `body` | id, x, y, health, team, flavour, archetype, lane, along, across, path index, node from, node to, progress |
| `gone` | id — written once when a body leaves, then forgotten |
| `stone` | index, health, alive |
| `end` | tick, winner |

Keyframes are delta-encoded against the previous keyframe: a body appears only when
one of its quantised numbers has changed. The `end` record is written by `M.close`
rather than by whoever ran the match, so a replay cut short by a crash is **missing
its last line** and says so by being missing it, rather than looking complete and
being wrong about the winner.

## The rules stamp

One integer over every number that shapes a match, computed by walking the
parameter tree with keys visited in sorted order — numbers before names, so that
printing the walk to find out why two stamps differ reads sensibly.

Computed rather than written down by a person, because a version number a person
maintains is wrong the first time somebody edits a catalogue without thinking about
replays. Change a soldier's health and the stamp changes; change a comment and it
does not. The project's own root path is skipped, because it differs on every
machine and has nothing to do with the rules.

A replay whose stamp disagrees is **refused rather than migrated**. Playing it
under the current numbers produces a match that diverges within seconds and blames
the replay system for it.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `M.begin` | `world` | nothing — hangs the log on the world, not recording. Called from the tick's assembly, after the structures exist |
| `M.record_into` | `world`, `path` | the path — opens the file, writes the header and an opening keyframe |
| `M.record_commands` | `world` | nothing — the tick's `record` row; returns immediately when nothing is recording |
| `M.log_keyframe` | `world`, `forced` (boolean) | nothing — the tick's `log` row |
| `M.close` | `world`, `winner` (integer) | how many keyframes were written |
| `M.read` | `path` | a replay record (below) |
| `M.check_rules` | `replay`, `parameters` | `true`/`false`, and this program's stamp |
| `M.rules_stamp` | `parameters` | integer |
| `M.hash_world` | `world` | integer |
| `M.compare_keyframe` | `world`, `keyframe`, `correcting` (boolean) | bodies compared, bodies unreconcilable, mean distance in world units |
| `M.play` | `world`, `replay`, `tick_module`, `correcting`, `until_tick` (0 for the end) | a report (below) |

`M.KEYFRAME_EVERY` is 30 — once a second, which is the rate the network layer
reconciles at. A replay keyframe and an accepted authority snapshot are the same
thing seen from two sides.

## Data structures it owns

### The log, hung on every world by `M.begin`

Present whether or not anything is being recorded. **Not recording is a state, not
an absence:** the sink is the integer 0 rather than nil, so the tick's rows ask
whether the sink is zero instead of asking whether a field exists.

| Field | Type | Meaning |
| --- | --- | --- |
| `sink` | 0, or an open file | where records are being written |
| `path` | string | what was opened |
| `every` | integer | ticks between keyframes |
| `previous` | array, one slot per soldier slot | 0, or the last quantised tuple written for that body |
| `previous_stone` | array, one per structure | 0, or `{health, alive}` |
| `written` | integer | keyframes so far |
| `commands` | integer | commands so far |

`previous` is allocated for **every** slot the world can hold rather than filled in
as bodies appear, so that no lookup here is a question about whether a key exists.

### A replay, from `M.read`

| Field | Type | Meaning |
| --- | --- | --- |
| `format`, `seed`, `rules`, `every`, `team_size`, `opening_tick` | numbers | the header |
| `player` | array of `{commander, team}` | who was playing |
| `command_at` | table, tick → array of commands | most ticks have no entry |
| `keyframe` | array in written order | each with `tick`, `hash`, `phase`, `challenge_index`, and a `change` list |
| `keyframe_at` | table, tick → index into `keyframe` | |
| `ended_at`, `winner` | numbers | absent if the file was truncated |
| `truncated` | true, only if the `end` record was missing | |

### The report, from `M.play`

| Field | Meaning |
| --- | --- |
| `ticks` | how far it got |
| `frames` | keyframes checked |
| `agreed` | how many matched the recorded hash exactly |
| `first_drift` | the tick of the first disagreement, or 0 |
| `corrected` | body-observations reconciled |
| `missing` | body-observations that could not be — dead here, or in a different lane |
| `worst_gap` | the largest mean distance from the record at any keyframe, in world units |
| `last_gap` | the mean distance at the final keyframe |

## Where it sits in the tick

Two rows, and the split is forced by when the queue exists:

- **`record`** runs after `think` and **before** `commands`, because applying
  commands empties the queue — and because a refused command still belongs in the
  record. A replay holding only accepted commands is a replay in which nobody ever
  made a mistake, and the refusals are half of what anybody watches a replay to
  understand.
- **`log`** runs last, after the snapshot, because a keyframe is a statement about
  a finished tick.

Putting the recorder in meant lifting the bots out of the command row into a
`think` row of their own — the recorder sat between the two and saw an empty queue,
because the thing filling the queue was inside the row after it. Which is the
argument for the dispatch table in the first place: a system folded into another
system's function body is a step that happens and cannot be seen happening.

## Related

- [Snapshots and replays](../issues/107-snapshots-and-replays.md)
- [The simulation tick](../docs/003-the-simulation-tick.md)
- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)
- [Open questions](../docs/020-open-questions.md), H1 and H2 — both found here
- `042-the-tick` — owns the two rows
- `043-snapshot` — the other thing called a snapshot, and a different thing
