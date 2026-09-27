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

The tool names a project's RAM scratch space after its folder — both tiers
of it — and every case's design folder is called `design`, so every case
would share one scratch space. The machine therefore makes both doors
first: `design/tmp` → `/tmp/burner-of-down-things/cases/<key>`, and inside
it `shared-memory` → `/dev/shm/burner-of-down-things/cases/<key>`. The tool
honours doors that already exist. `<key>` is the case name and 8 hex
characters of the SHA-256 of the case folder's path, so two cases with the
same name in different places never share scratch space.

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

## Workflows: the checks delivery trusts

> the user is expected to test their own application. The system should
> make workflows that use the same types of input that the user would
> provide, to test behavior from end-to-end. […] Protocols, not procedures.
>
> — the owner, 2026-09-27

An issue's acceptance commands run tests the build turn wrote in the same
turn as its code. That is the builder's own check, useful for repair, but
a referee that shares anything with what it grades grades nothing (the
strategem *other people's software as a rubric*, rao-chat). So before the
first wave a **referee** turn, which reads the blueprint and nothing else,
writes end-to-end **workflows** into the case's `workflows/` folder: shell
scripts that use the design as a person would — the commands they type,
the files they hand it — and check only what a person could see. Build
and repair turns can neither see nor write them.

```
  blueprint ──referee turn──► workflows/NN-*.sh ──each must FAIL on an empty folder──► refereed
                                                   (a workflow that passes with
                                                    nothing built checks nothing)
  … waves, each issue's own acceptance …
  every workflow, run in the design ──fail──► repair every issue it covers (output only, not the text)
            │ pass                              up to 2 rounds, then workflow-failed: not delivered
            ▼
        delivered
```

After a request's amend the workflows are written again from the amended
blueprint, so the rebuilt design is checked against the changed behaviour.

## Why waves

Level by level is the only order in which every build turn can be handed
working code for everything it builds on. Within a level no issue builds on
another, so the level's turns can run together. The number of turns running
at once is the pool size ([005](005-datapath-the-hands.md)).

## Delivered

When every issue has `built` and the final full acceptance run passes, the
machine writes `output/delivered`: the design's path, the count of issues,
the count of turns spent, and the `delivered` line's number and hash — the
fingerprint of the history that produced it. A build run that builds
nothing over an already-delivered design appends no second `delivered`
line: nothing happened, and the ledger records only what happened.
