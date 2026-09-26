# 007 — Datapath: the design

The design is new code built from the blueprint alone, one wave at a time.
Each issue is built by one turn, then checked by running the commands its
Acceptance section names. The design is delivered when every issue has
passed: *the harness and etceteras*.

```
  the graph ──levels──► wave 0: [101, 102, 103]    build turns in parallel
                              │
                              ▼
                        run each issue's acceptance commands in design/
                              │
                   pass ──────┴────── fail
                    │                   │
               ledger: built       repair turn, given the output (up to 2)
                    │                   │
                    │             still failing → build-failed; its reach is held
                    ▼
                  wave 1: issues whose blockers all passed …
```

## The design folder

`design/` is laid out as a house project the first time a build runs:
`src/`, `docs/`, `tests/`, `issues/`, `input/`, `output/`, and a `README`
saying which case it was built for. The layout comes from the owner's
project-init tool when it is present (`init-project.sh --skeleton-only`);
when it is not, the machine stops and says so rather than inventing a
layout of its own.

The tool names a project's RAM scratch space after its folder, and every
case's design folder is called `design`, so every case would share one
scratch space. The machine therefore makes the design's `tmp` link first,
pointing at `/tmp/burner-of-down-things/cases/<case name>/`, and the tool
honours a `tmp` link that already exists.

Each build turn is told:

- its issue file, whole;
- the issue files of everything it is built on, whole;
- the case's target (the person's words from `input/target`), or "the same
  kind of software as the one described";
- that the source is not available and not to be asked for;
- to write code under `design/src/` and tests under `design/tests/`, and to
  make the issue's Acceptance commands pass.

## Acceptance

The machine runs each Acceptance command with the design folder as its
working directory, one at a time, with a time limit, and captures its output.
Exit status 0 is a pass. These are commands a model wrote; the machine runs
them only inside the design folder, and the person is told so the first
time a case builds.

| Decision | What each path leads to |
|---|---|
| All of an issue's commands pass | `built` in the ledger |
| One fails | A `repair` turn gets the issue, the command and its output. Up to two repairs |
| Still failing after the repairs | `build-failed`; every issue in its reach is held, and the rest of the wave's reach continues |
| An issue has no Acceptance commands | Not built: it goes back to a describe turn. An issue with no checks cannot be said to pass |
| A build turn changed a file that an already-built issue's acceptance depends on | Found when the whole design's acceptance is re-run at the end of every wave: every built issue is checked again, and any that now fail are repaired first |

## Why waves

Level by level is the only order in which every build turn can be handed
working code for everything it builds on. Within a level no issue builds on
another, so the level's turns can run together. The number of turns running
at once is the pool size ([005](005-datapath-the-hands.md)).

## Delivered

When every issue has `built` and the final full acceptance run passes, the
machine writes `output/delivered`: the design's path, the count of issues,
the count of turns spent, and the ledger's head hash at the moment of
delivery — the fingerprint of the history that produced it.
