# 008 — The Shape of the Code

House style. What every source file in this project looks like, and the handful of
rules that are not negotiable.

## Two programs, one canvas

The project builds **two executables** that share the code for drawing the
painting and nothing else:

| | |
| --- | --- |
| **the game** | reads the fence network. Never writes it. |
| **the tracing tool** | writes the fence network. See [the tracing tool](004-the-tracing-tool.md). |

This is the project's instance of the general rule that **data generation and
data viewing stay separate**. Defining what the city is, is generation. Playing
it, is viewing. Keeping them apart means the tracing tool can be as dense and
keyboard-driven as it likes, and means the game physically cannot corrupt the
network because it contains no code that writes one.

Within the game the same split repeats: a filter's **reading** — the number it
gives each block — is generated separately from the **hatching** that draws it.
The reading should be computable and checkable with nothing on screen at all.

## Language

Lua, written to LuaJIT-compatible syntax. No Lua 5.4 constructs. LÖVE for the
window and the drawing.

## Files

Every source file carries an index at the front of its name, and the indices count
up across the **whole project** from the single counter at `.file-index-counter`
— not per directory. Reading from the lowest number upward is meant to be a
narrative that explains the project, so the numbers mean reading order, not the
order things were written. Renumbering when the story changes is expected.

Every source file has a companion `name.info.md` beside it listing the functions
it offers, their inputs and outputs, and what each is for — treating them as
black boxes. **Prefer reading the companion over reading the source**, unless
chasing a specific bug in a specific function.

Every script begins with a comment saying what it is and roughly how it works,
pitched at somebody who will never read the code. Scripts run from any directory:
a hard-coded `${DIR}` at the top, overridable by an argument, and every path in
the script relative to it.

## Functions are folded

Each function opens with a comment naming it without arguments, then the
definition:

```lua
-- {{{ local function trace_adopt_edge()
local function trace_adopt_edge(network, edge_index, direction)
    ...
end
-- }}}
```

The closing fold marker goes on its own line below the last line of the function.

## Dispatch tables, not chains

Wherever a chain of if-else or a switch appears, it becomes a table keyed on the
thing being tested. Referring to a function or a value by index is cheaper than
walking a chain of comparisons, and it is easier to read a table of cases than a
staircase of branches.

The tracing tool's click handling is the clearest example: what a click does
depends on whether empty painting, a vertex, or an edge is under the cursor, and
that is three table entries rather than three branches.

## Fallbacks are warnings, warnings are errors

**Prefer a loud failure to a quiet substitution.** If something is missing, say
so and stop. Never silently pick a default and carry on.

Where a fallback genuinely exists it must announce itself every time it is used,
and an issue file must exist to remove it. A fallback nobody has noticed is a bug
that has been running for months.

There are no nil checks in place of understanding. If a value could be absent,
find out **why** it could be absent and fix that, rather than testing for it at
the point of use.

## Comments explain why, and what each branch would mean

Comments do not restate what the code does. They record **why it is this way**,
and how it came to be, where that is interesting.

Every branch gets a comment saying what each path would bring — not "if the edge
is shared" but what a shared edge means for the block on the far side. Branch and
comment are one thing and are updated together.

Anything learned about a data format, or any consideration that will be needed
again the next time somebody touches a section, goes in as a comment at the place
it matters. If a fact will be needed more than once, it is written down where it
is needed.

## Where files live at runtime

Two RAM-backed tiers, reached through the project's `tmp/` symlink:

| Path | Backed by | For |
| --- | --- | --- |
| `tmp/` | `/tmp/enheim-tome` | executable scratch |
| `tmp/shared-memory/` | `/dev/shm/enheim-tome` | logs, autosaves, converted textures, anything not executed |

Run scripts create these before writing to them. Nothing in either is ever
committed.

`input/` is read first, at startup. `output/` is written last; goodbye goes
there.

## Tests

Cheap, and there should be many. They run as part of every build.

Whenever a bug is fixed, a test is written that would have caught it — not
because a process demands it, but because the bug will otherwise come back and
nobody will remember it was ever gone.

The fence network in particular has invariants that can be checked without a
window: no edge named by three blocks, every loop closed, every block named. See
[the fence network](003-the-fence-network.md).

## Related documents

- [The tracing tool](004-the-tracing-tool.md) — the second program
- [Roadmap](009-roadmap.md)
