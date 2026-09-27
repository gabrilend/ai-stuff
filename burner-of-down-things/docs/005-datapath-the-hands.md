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
| `describe` | an issue id | source, survey, `blueprint/outline.tsv` | `blueprint/issues/<id>-…` only | issue-lifecycle |
| `build` | an issue id | blueprint, design | `design/` | whatever the person lists in the case's `input/crafts` (canvas-and-paintbrush, polyglot-source, …) |
| `repair` | an issue id | blueprint, design, the failing test output | `design/` | same as build |
| `referee` | `-` | blueprint only | `workflows/` | none |
| `locate` | a request | the request, blueprint | its own turn folder (`touched`) | none |
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
| `command` | function | given the project and a turn, returns the program line that runs one turn; the machine wraps it with `timeout` and sends its output to the turn folder |
| `cost` | string | `subscription`, `per-token` or `free` |
| `pool` | number | turns at once by default: 4 for `claude-code`, 8 for `stand-in` |
| `limit` | number | seconds before a turn is stopped: 1800 for `claude-code`, 60 for `stand-in` |

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
each kind receives; build and repair turns also receive every skill the
person names, one per line, in the case's `input/crafts` — that file is how
the person says which of their crafts a design should be built with. The
hands read each file and place it in `instructions.md`, which is refused
above 120 KiB (Claude Code receives it as one argument, and the kernel holds
one argument to 128 KiB). If a named craft's file is missing, the turn is refused,
naming it — a turn that was meant to build the owner's way and cannot is not
started without saying so.

## Many turns at once

Turns that do not depend on each other — the describe turns of a blueprint,
the build turns of one wave — run at the same time, in a pool of worker
threads each starting one harness process and waiting for it. The pool's
size is a setting (the harness row's `pool` unless a run says otherwise). Snapshots are taken once before the whole set and
once after it, and each changed path is charged to the turn whose writable
prefix holds it most specifically; describe turns each write only their own
`blueprint/issues/<id>-` prefix, so their files are charged exactly. Build
turns share `design/`, so their files are charged to the whole wave. A change
that no turn of the set may write cannot be traced to one turn — they ran
together — so it makes every turn of the set a breach.

Snapshots hash every file once, on every core, and later reuse the checksum
of any file whose size and time have not moved (kept between runs in
`turns/snapshot.tsv`). Files over 64 MiB are known by size and time alone:
one 943 MB git pack file in a source made a first snapshot take 14 seconds
instead of 1.5. The cost: such a file rewritten with identical bytes counts
as a change.

The folders a Claude Code turn can reach are named with a trailing slash in
the kinds table. Without it a folder is reached through its parent — the
whole case, including `turns/`, where earlier turns' records can quote the
source. The phase 3 demo found this; a check now holds it.
