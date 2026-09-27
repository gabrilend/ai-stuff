# 601 — Locate and grade

Finding which issues a request touches, and deciding its grade from the
graph ([008](../docs/008-datapath-the-update.md), *the grade*).

## Current Behavior

Built as `src/053-grading.lua`, with the `grade` command in `src/056-the-update-commands.lua`. The grade line lives in one table (`RULE`: foundation at level 0 or at half the blueprint). The `graded` line's text is parsed back when a held request is released, so a grade is decided once. Checked by tests/057 at every edge of the rule on six-issue graphs (a level-1 leaf is surface; a reach of 2 of 6 is middle; exactly half is foundation), plus a locate turn answering an unknown id first and a good id second.

## Intended Behavior

- **Locate** (case, request): one `locate` turn; its prompt holds the
  request text and every issue's id, name and Intended Behavior; it writes
  `touched` in its own turn folder: one id per line, or `new <phase>` lines.
  The machine checks each id exists; a bad answer gets a new turn told which
  ids exist, up to three.
- **Grade** (graph, touched): reach (402); `surface` when every touched issue
  has no blocks and no line is `new` in a phase below the highest; `foundation`
  when a touched issue is level 0 or the reach is at least half the graph;
  else `middle`. The line between grades is one table (the grade table), so
  moving it is a one-row change recorded in `docs/balance-updates.md`.
- Appends `graded` (text: grade, touched, reach) and writes
  `output/<request>.grade` for the person.
- **Command `grade`** locates and grades one request and changes nothing
  else.

## Suggested Implementation Steps

1. Grade. **Test:** on a six-issue fixture graph: a leaf is surface; a
   level-1 issue whose reach is 2 of 6 is middle; one whose reach is 3 of 6
   is foundation (the half line, exactly at its edge); a level-0 issue is
   foundation.
2. Locate with the stand-in. **Test:** a bad id then a good answer; two
   turns.

## Blocked by

- 402
- 306
