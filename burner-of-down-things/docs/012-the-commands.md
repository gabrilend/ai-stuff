# 012 — The commands

The machine is started by one script at the project root, `machine`, which
takes a command and a case name. Every command reads the case's `input/`
first and writes `output/goodbye` last ([003](003-datapath-the-case-and-the-ledger.md)).

| Command | Does | Built in phase |
|---|---|---|
| `machine open <case> <source folder> [harness]` | makes the case folder, its record and its first ledger line | 1 |
| `machine ledger <case>` | verifies the chain and prints its length and head hash | 1 |
| `machine survey <case>` | reads the source into `survey/` | 2 |
| `machine summary <case>` | rebuilds and prints the survey's summary from its tables | 2 |
| `machine describe <case>` | outline, then every issue, into `blueprint/` | 4 |
| `machine graph <case>` | prints the blueprint's graph level by level | 4 |
| `machine build <case>` | builds every issue not yet built, wave by wave | 5 |
| `machine update <case> [--go]` | handles waiting requests in `input/` | 6 |
| `machine grade <case> <request>` | locates and grades one request without changing anything | 6 |
| `machine center <case>` | computes and prints the center | 7 |
| `machine run <case>` | whatever the case is waiting for, in order: survey, describe, build, update | 7 |
| `machine view <case>` | writes the case's HTML page | 7 |

The commands are one dispatch table in the source: a row per command, with
the function that runs it and whether it needs the case lock (every command
that appends to the ledger does). An unknown command prints the table.

`machine` takes an optional first argument naming the project folder, for
running a copy of the machine from elsewhere; the default is written at the
top of the script.
