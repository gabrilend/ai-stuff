# 005 — Datapath: the hands

The machine's own code decides what to do, in what order, and whether it
worked. The reading and writing of prose and code is done by a model, one
**turn** at a time. The hands are the part that starts a turn, keeps it inside
its folders, and checks afterwards that it stayed there.

```
  a job (kind, about)
     │
     ▼
  make turns/NNNN-kind-about/
     ├─ prompt.md          from the prompt table, row = kind
     ├─ instructions.md    rules for this kind + its crafts + the center
     └─ confinement.lua    reads / writes for this kind, as absolute paths
     │
     ▼
  snapshot: every file under the case folder and the source → size, time, checksum
     │
     ▼
  harness row's start_turn (a process; waits for it to exit, up to the time limit)
     │
     ▼
  snapshot again → compare → verdict: kept | breach | failed
     │
     ▼
  ledger: turn-started … turn-ended (+ breach)
```

## The turn kinds

| Kind | About | Reads | Writes | Crafts it is handed |
|---|---|---|---|---|
| `outline` | `-` | source, survey | `blueprint/outline.tsv` | issue-lifecycle |
| `describe` | an issue id | source, survey, `blueprint/outline.tsv` | `blueprint/issues/` | issue-lifecycle |
| `build` | an issue id | blueprint, design | `design/` | project-init, polyglot-source when the target asks for more than one language |
| `repair` | an issue id | blueprint, design, the failing test output | `design/` | same as build |
| `locate` | a request | the request, blueprint | `turns/…/touched` | none |
| `amend` | a request | the request, blueprint | `blueprint/issues/` | issue-lifecycle |

**The clean room:** no turn of kind `build` or `repair` can read the source.
It is not in their read list, and the Claude Code harness is started so that
its file tools refuse any path outside the listed folders. Whatever the
design gets right, it got from the blueprint.

## Confinement, twice

| Layer | How | Catches |
|---|---|---|
| Before: the harness's own limits | Claude Code is started in restricted mode, working in the first writable folder, with the other folders added; its file tools cannot reach outside them; its command-running tools are removed; writes to read-only folders are denied by a settings rule | A turn trying to read the source during a build, or to run a command |
| After: the snapshot comparison | Every file under the case and the source, before and after; any created, changed or removed path outside the writable list is a breach | Anything the first layer missed, and any harness that has no limits of its own (the stand-in has none) |

| Decision | What each path leads to |
|---|---|
| The comparison finds a change in the source | Breach. The run stops. The source is the person's; the machine never writes to it and does not try to repair it |
| A change outside the writable list, elsewhere in the case | Breach. The turn's work is not accepted, the ledger records every path, and the run stops for the person |
| The harness exits non-zero, or runs past its time limit | `failed`, the exit reason recorded. Its writes, if inside the list, stay for the next turn to see |
| The harness's needed program is not installed | Refused before the first turn, naming it |

## The harness table

One row per harness, the same fields each. Adding a harness is adding a row.

| Field | Type | Holds |
|---|---|---|
| `name` | string | `claude-code`, `stand-in` |
| `needs` | array of strings | programs that must be on the path |
| `start` | function | given a turn folder and its confinement, returns the command line that runs one turn |
| `cost` | string | `subscription`, `per-token` or `free` |

**`claude-code`** runs `claude -p` with the prompt, the instructions appended
to its system prompt, single-JSON output, restricted mode, only the file tools
(read, write, edit, find, search), edits accepted without asking inside its
folders, and anything else that would ask refused. Its JSON result is kept as
`result.json`.

**`stand-in`** is a small Lua program that does what a well-behaved turn of
each kind would do, from fixture text, with no model. It exists so every part
of the machine above the hands can be tested and demonstrated without
spending anything. It can be told to misbehave (write outside its folders,
exit non-zero) so the checks can be tested too.

## Crafts

A craft is one of the owner's skill files
(`~/.claude/skills/<name>/SKILL.md`). The turn kinds table names which crafts
each kind receives; the hands read each file and place it in
`instructions.md`. If a named craft's file is missing, the turn is refused,
naming it — a turn that was meant to build the owner's way and cannot is not
started without saying so.

## Many turns at once

Turns that do not depend on each other — the describe turns of a blueprint,
the build turns of one wave — run at the same time, in a pool of worker
threads each starting one harness process and waiting for it. The pool's
size is a setting (default 4 for a subscription harness, every hardware
thread for the stand-in). Snapshots are taken once before the whole set and
once after it, and each changed path is charged to the turn whose writable
folder holds it; two turns in one set never share a writable folder that is
not split by issue, so the charge is never ambiguous for `describe`. For
`build`, whose turns share `design/`, a path is charged to the whole wave,
and a breach stops the wave.
