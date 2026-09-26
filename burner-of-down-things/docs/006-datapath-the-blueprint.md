# 006 — Datapath: the blueprint

The blueprint is the source written down as issue files, in the same house
format the owner's own projects use: numbered by phase and by foundation,
each with its current behavior, intended behavior and implementation steps,
each naming the issues it is built on. A reader of the blueprint alone should
be able to build the software.

```
  survey ──► outline turn ──► blueprint/outline.tsv
                                   │ checked by the machine:
                                   │   ids well-formed and unique
                                   │   every blocker exists, no cycles
                                   │   every code file in the survey covered
                                   ▼
                             the graph (levels)
                                   │
                ┌──────────────────┼──────────────────┐
                ▼                  ▼                  ▼
          describe 101       describe 102  …    describe 305      (in parallel)
                │                  │                  │
                ▼                  ▼                  ▼
          blueprint/issues/101-….md  …                            checked each:
                                                                    sections present
                                                                    Blocked by = outline's
                                                                    validate-issues --file
```

## The outline

One turn reads the survey and the source and plans the whole blueprint at
once: which issues, in which phases, built on which, covering which files.
Planning all at once is what lets the numbering follow the house rule —
foundations get low numbers because others build on them — which a
file-by-file description could not know.

The outline is a table ([002](002-the-terms.md), *an outline row*), so the
machine can check it without a model:

| Check | A failure means |
|---|---|
| Each id is a phase digit and two digits; no id twice | The outline is sent back to a new outline turn with the failures listed |
| Each name is lower-case words joined by dashes | Same |
| Each blocker is an id in the outline | Same |
| Following blockers never returns to where it started | Same, naming the cycle |
| Every survey row with role `code` or `build` is in some issue's `covers` | Same, naming the uncovered files |
| Covers names a path the survey does not have | Same |

After three failed outline turns the run stops and the failures go to the
person: an outline that cannot converge is a sign the source needs a person's
eye, not another turn.

## The graph

Read from the outline (and, once issue files exist, from their *Blocked by*
lines, which must agree with it). Each issue's level is 0 when nothing blocks
it, else one more than the highest level among its blockers. The levels are
the build order: all of level 0, then all of level 1, and so on.

The same graph grades requests ([008](008-datapath-the-update.md)): an issue's
**reach** is itself plus everything that is built on it, directly or not.

## An issue file

Written by a `describe` turn, one per outline row, into
`blueprint/issues/<id>-<name>.md`:

| Section | Holds |
|---|---|
| title line | `# <id> — <name in words>` |
| Current Behavior | In a blueprint, the state of the design for this piece — at first, that nothing is built |
| Intended Behavior | What this piece does, its data and its decisions, precise enough to build without the source |
| Suggested Implementation Steps | Numbered, each with the test that shows it works |
| Acceptance | The checks a build of this issue must pass, as commands to run in the design folder — the machine runs exactly these |
| Blocked by | The outline's blockers, as ids |
| Covers | The source files it describes (for the record; the build turn never sees them) |

| Decision | What each path leads to |
|---|---|
| A described issue lacks a section, or its Blocked by differs from the outline | A new describe turn for that issue, given the finding |
| `validate-issues --file` reports on it | Same |
| Three describe turns fail for one issue | That issue is left undescribed, recorded as `describe-failed` in the ledger, and everything it blocks is held |

The blueprint's issues are never moved to a completed folder: they are the
specification, and they stay open. What is built is recorded in the ledger.
