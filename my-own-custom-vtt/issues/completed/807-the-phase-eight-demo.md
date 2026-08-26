# 807 -- The phase eight demo

**Phase:** 8, content generation
**Blocked by:** every other issue in phase 8.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 7. Every world in every one of them is
the same two-room fixture.

## Intended behaviour

**A written description and a seed become a dungeon**, and the demo shows the
chain rather than the result.

### What it shows

**The description, printed.** A few lines somebody could have typed.

**Each stage's output.** The graph as nodes and edges; the geometry as counts;
the furnishing as what the ruleset chose to put in each room. Four stages, four
reports — because the point of the split is that each is separately answerable.

**The same seed twice, byte-identical.** A description plus a seed is a few
hundred bytes naming a whole dungeon exactly.

**One line changed, and what changed.** Add a room; show the graph gaining a node
and the geometry gaining an outline. That is the difference between a map you can
edit and a map you can only replace.

**The same layout furnished by two rulesets.** The layout stage never learned what
a tavern was, and this is where that becomes visible.

**A description that cannot be satisfied, refused by name.** Ask for nine rooms in
a space that holds four, and show the sentence.

**And the world drawn**, in the terminal, the way phase 2 drew the fixture — so
that "a description became a place" is something to look at rather than a table
of counts.

### Then walk into it

Finish by running a body through the generated dungeon and folding its fog, the
way phase 2 did. Every phase before this one used a hand-written fixture; this is
where the project stops needing one.

## Suggested implementation steps

1. Write two or three descriptions in `input/`, since that is where a program's
   opening decisions live.
2. Report each stage.
3. Regenerate and compare bytes.
4. Show the edited description and the diff in counts.
5. Provoke the unsatisfiable case.
6. Draw the result, and walk a body through it.
7. Confirm `./run-phase-demo 8`.
