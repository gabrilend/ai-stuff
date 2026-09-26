# 002 — The terms

The words every other document, issue and source file uses, and the shape of
the data behind each one, down to plain strings and numbers.

## The things

| Term | What it is |
|---|---|
| **the machine** | This project. It has no name ([001](001-what-it-is.md)) |
| **the person** | Whoever hands the machine software and asks for changes |
| **a case** | One piece of software being handled: its folder holds everything the machine knows and has made about it |
| **the source** | The software the person handed over, as a folder of source code. Read, never written. The machine checks it is unchanged after every turn |
| **the survey** | What is in the source, found without a model: files, languages, sizes, and which file includes which |
| **the blueprint** | The source described as issue files in the house format. The specification the design is built from |
| **an issue** | One file of the blueprint: one piece of the software, what it does, what it builds on, how to check it |
| **the graph** | Which issue builds on which, read from each issue's *Blocked by* line |
| **a level** | Issues whose blockers are all in earlier levels. Level 0 is the foundation |
| **a wave** | One level's issues built at the same time, in parallel |
| **the design** | New source code built from the blueprint alone |
| **a turn** | One run of a model, started by the machine, aimed at one job, allowed to write only in named folders |
| **a harness** | The program that runs a turn: Claude Code, or the stand-in used by tests |
| **confinement** | The rule of which folders a turn may read and write, and the check after it ends that it kept to it |
| **a breach** | A turn that changed something outside what it was allowed to write |
| **a request** | A change the person asks for, written as a file in the case's `input/` |
| **a grade** | How deep a request reaches into the graph: surface, middle or foundation |
| **the ledger** | The case's append-only record of everything that happened, each line chained to the one before it by a checksum |
| **the center** | What the machine attends to first, computed from the ledger alone. Its personality |
| **a craft** | A skill file the machine hands to a turn so the turn builds the way the owner builds |

## The data

### The case record — `case.lua`

A Lua file returning one table. Written once when the case opens, rewritten
only when the person changes the harness or the target.

| Field | Type | Holds |
|---|---|---|
| `name` | string | the case's folder name, lower-case words and dashes |
| `source` | string | absolute path of the source folder |
| `opened` | string | date and time the case was opened, `YYYY-MM-DD HH:MM:SS` |
| `harness` | string | a row name in the harness table: `claude-code` or `stand-in` |
| `target` | string | the person's words for what the design should be — language, platform, anything. Empty means "the same kind of thing as the source" |

### A ledger line — `ledger`

One line per event, fields separated by tabs, never edited or removed.

| Field | Type | Holds |
|---|---|---|
| `seq` | integer | 1 for the first line, one more for each after |
| `time` | string | `YYYY-MM-DD HH:MM:SS` |
| `kind` | string | what happened (the table in [003](003-datapath-the-case-and-the-ledger.md)) |
| `about` | string | what it happened to: an issue id, a request file name, a turn id, or `-` |
| `text` | string | a sentence, with tabs and newlines escaped as `\t` and `\n` |
| `prev` | string | the previous line's `hash`, 64 hex characters; 64 zeroes for line 1 |
| `hash` | string | SHA-256 of the five fields before `prev` plus `prev`, joined by tabs |

### A survey row — `survey/files.tsv`

| Field | Type | Holds |
|---|---|---|
| `path` | string | the file's path relative to the source folder |
| `language` | string | from the extension table: `lua`, `c`, `shell`, `markdown`, … or `other` |
| `lines` | integer | newline count |
| `bytes` | integer | size |
| `role` | string | `code`, `doc`, `data`, `build` or `binary` |

### A survey link — `survey/links.tsv`

| Field | Type | Holds |
|---|---|---|
| `from` | string | the file that includes |
| `to` | string | the file included, relative to the source, or the name as written when it is outside the source |
| `kind` | string | `require`, `include`, `import`, `source` |
| `inside` | string | `yes` when `to` is a file in the source, `no` otherwise |

### An outline row — `blueprint/outline.tsv`

The plan of the blueprint, written by the outline turn before any issue is.

| Field | Type | Holds |
|---|---|---|
| `id` | string | the issue id, house shape: phase digit then two digits (`101`, `203`) |
| `name` | string | dash-separated lower-case words |
| `blocked_by` | string | ids separated by spaces, or `-` |
| `covers` | string | source paths separated by spaces: the files this issue describes |

### A graph node (in memory)

| Field | Type | Holds |
|---|---|---|
| `id` | string | issue id |
| `file` | string | path of the issue file |
| `blocked_by` | array of strings | ids |
| `blocks` | array of strings | ids, the reverse edges, computed |
| `level` | integer | 0 when `blocked_by` is empty, else one more than its highest blocker |

### A turn folder — `turns/NNNN-kind-about/`

| File | Holds |
|---|---|
| `prompt.md` | what the turn was asked |
| `instructions.md` | the standing instructions it was given: rules, crafts, the center |
| `confinement.lua` | the table of paths it may read and may write |
| `result.json` | what the harness printed (for Claude Code: its single JSON result) |
| `verdict` | `kept`, `breach` or `failed`, and why, one line each |

### A request — `input/*`

Any file the person drops into the case's `input/`. Its name is its id. The
machine marks it handled by a ledger line, never by moving or editing it.

### The grade

| Grade | Means |
|---|---|
| `surface` | Every touched issue is a leaf: nothing is built on it. Only those issues are rebuilt |
| `middle` | Some touched issue has others built on it. Those, and everything above them, are rebuilt |
| `foundation` | Some touched issue is in level 0, or the rebuild reaches half the blueprint or more |
