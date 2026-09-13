# 307 — A factory is a line you did not design

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 108, 305, 306 |
| Blocks | 308, 402, 504 |
| Reads | [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) |
| Open questions | A5 |

## Current behavior

Nothing. Units can be spawned into the world directly (issue 201) for the phase
2 tests, but nothing in the simulation produces one: there is no factory, no
line, and no verb at the command door for placing either.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that a factory is placed by one command carrying its cell,
domain, line and pattern; that its line produces its entries in order and wraps
unless placed one-shot; that each entry is a construction stream (issue 305)
finishing as a unit on the field; that a sea factory must stand on a shore cell
and an air factory's output goes to the cloud; and that a stop command halts
production without touching the pattern. The factories document describes the
line.

## Intended behavior

The vision's phrase: production lines that "you don't have to design them,
they're already pre-factored built. just construct them." A **factory** is a
building on a held cell with a **domain** — land, air, or sea — and a **line**:
an ordered list of unit kinds it produces, drawn from a catalogue of lines the
game ships with. The player picks a line; the player does not compose it. This
is what makes it a factory game — you design the flow, not the parts.

A line is a queue. It produces its entries in order and, when it reaches the
end, starts again unless the factory was placed one-shot. Each entry is a build
opened on the construction stream, drawing the entry's cost from the cost table
(issue 306) at the team's share of build power; when the stream finishes, the
emit pass places the unit (issue 201) at the factory's cell carrying a copy of
the factory's pattern (issue 308), and the line advances.

Placement is one command through the door (issue 108), carrying the cell, the
domain, the line index, the one-shot flag, and the pattern, all at once, because
the pattern must exist before the first unit does. The door validates before
placing and **refuses by name**: a cell not held by the team, a domain that
cannot stand there (a sea factory must sit on a land cell with water beside
it; a land factory on land; an air factory on land), a line index the catalogue
does not hold, or a pattern that fails issue 308's checks. A refused placement
places nothing and repairs nothing.

A factory under construction is a factory with no line running yet: placement
opens a build for the factory itself, and the line starts when it finishes. Per
the working ruling in A5, two more verbs exist: **stop**, which halts the line
without touching the pattern, and **resume**; and a factory may be
**demolished** for a share of its mass. A stopped factory's units keep
following the drawing they left with.

An air factory's output follows no pattern: a finished plane's mission is
to-cloud (issue 402). A sea factory's output appears on the water cell beside
it. Carriers — factories that move — are issue 504, and the factory row is
given a position rather than only a cell so that they can be.

## Suggested implementation steps

1. Claim the `factories` stem with `./new-source-file`. Add a factory
   array-of-arrays to the world: `cell`, `x`, `y`, `team`, `domain`, `line`,
   `entry` (which entry is next), `one_shot`, `running`, `standing`, `build` (the
   open build's id, zero for none), `pattern` (indexes the pattern arrays of
   issue 308), all integers; allocated once, live count, free list.
2. Claim a `lines` catalogue table under `assets/`: one row per line, holding a
   domain and an ordered list of unit kinds. The loader refuses a line whose
   kinds' domains disagree with the line's.
3. Export `place(world, team, cell, domain, line, one_shot, pattern)`: every
   check above, each refusal a named string returned to the door; on success a
   factory row and a build for the factory itself. Export `stop`, `resume`, and
   `demolish`. Add the four verbs to the door's dispatch table.
4. Export `emit_pass(world)`: for each standing, running factory with no open
   build, open one for the current entry; the construction pass's finish handler
   for the factory opener spawns the unit with the pattern copy, advances
   `entry`, and wraps or stops per `one_shot`. Register it as the fourth row of
   the tick.
5. Make the domain-to-placement rule a dispatch table keyed by domain — where a
   factory may stand and where its output appears — so the sea and the air are
   rows, not branches.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: one placing command,
   in-order production, wrapping, shore rule, air output to the cloud, stop.

## Related documents and tools

- [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) — the line and the queue invariant
- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — what a finished unit copies at birth
- `tests/021-inflows-and-outflows.lua`
- issue 108 — the door the placing command enters by
- issue 305 — the stream every entry draws on
- issue 308 — the pattern placed with the factory

## Still open

- A5: whether a line can be stopped, resumed, or a factory demolished — the
  working ruling is all three; if demolition is refused, the verb goes and the
  cell stays occupied until the ground is lost.
- Which lines the demo ships, beyond one per demo kind. The catalogue decides;
  the shape here allows any.
