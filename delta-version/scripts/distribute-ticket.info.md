# distribute-ticket.lua

## Overview

Files one ticket template as a new, numbered issue in every project it is
for. It is the distribution step of the ticket chain (issue 019), and it
holds none of the chain's rules itself:

| Question | Answered by |
|----------|-------------|
| Which projects get the ticket? | `discover-projects.lua --paths` (same filters and profiles) |
| Which phase does it go into? | `scripts/libs/issue-names.lua`, the shared issue-name reader |
| Which number does it get? | `scripts/validate-issues PROJECT --next PHASE` |
| What does the ticket say in this project? | `libs/kml.lua` with `config/ticket-keywords.conf`, layered with the project's own `config/ticket-keywords.conf` |
| Has this project had it before? | the marker line at the end of each filed ticket |
| What was filed, where, and can it be taken back? | `assets/ticket-distributions.tsv`, the ledger |

## Usage

```
distribute-ticket.lua TEMPLATE --phase=N|current TARGETS [options]
distribute-ticket.lua --undo=D-YYYYMMDD-HHMMSS [--write]
```

Nothing is written unless `--write` is given. Without it the tool prints
the plan: each project, the file it would get and the phase, or why it is
skipped.

```
$ distribute-ticket.lua templates/readme-check.md --phase=current --language=c
my-own-custom-vtt                    would write issues/1310-check-the-readme.md (phase 13)
soren-ds                             would write issues/117-check-the-readme.md (phase 1)
...
4 project(s) chosen, 3 ready, 1 skipped; dry run, nothing written (add --write)
```

### Targets

At least one is required: a ticket never goes to every project by default.
`--projects=a,b` names them. Every `discover-projects.lua` filter is passed
through unchanged: `--profile`, `--language`, `--uses`, `--state`, `--has`,
`--active-days`, `--only`, `--exclude`.

### Phase and number

`--phase=N` files into phase N everywhere (N may be a capital letter for the
lettered phases some projects use). `--phase=current` gives each project its
lowest phase that still has open issues; a project with none open gets its
highest phase, and a project with no phased issues gets phase 1. The number
is whatever `validate-issues --next` says, so it follows the project's own
name shape (`102`, `9-008`, `A05`).

### Filling the template

Templates use the keyword markup language (`docs/keyword-markup-language-spec.md`):
`][project_name[]`, `][ticket_id[]` and so on. Commands run inside the
project. The default error mode here is `fail`, unlike the engine's own
default: a ticket with a keyword that could not be filled is not written,
and the line for that project says which keyword. `--error-mode=placeholder`
writes it with the unfilled keyword left visible instead.

The file name is `ID-SLUG.md`. The slug is the template's first heading, cut
to six words, unless `--slug=` gives one.

### Options

| Option | Effect |
|--------|--------|
| `--write` | write the tickets and record them in the ledger |
| `--show=PROJECT` | print the filled ticket that one project would get |
| `--again` | file it even where this template was already filed |
| `--create-issues` | give a project with no `issues/` one (`issues/` and `issues/completed/`); without it such a project is skipped |
| `--slug=words-like-this` | the file name's description |
| `--error-mode=MODE` | `fail` (default), `placeholder`, `remove`, `verbose` |
| `--undo=D-...` | take a distribution back out (see below) |
| `--ledger=PATH` | where the record is kept (tests point this at scratch) |
| `--dir=PATH` | the monorepo; default `/mnt/mtwo/programming/ai-stuff` |

## Safety

- **Never overwrites.** A ticket is written only to a file name that does not
  exist, checked again just before writing.
- **Re-runs are safe.** Each ticket ends with a comment line naming the
  template, the date and the distribution id. A project whose issues already
  hold that template's line is skipped ("already filed as ..."), so running
  the same distribution again reaches only the projects it missed.
- **Undo removes only untouched tickets.** The ledger keeps each ticket's
  sha256. `--undo` removes a ticket only while it still matches; an issue
  someone has edited since, moved to `completed/` or already removed is named
  and left alone. Undo is a dry run too until `--write` is given, and it adds
  an `undone` row for each ticket it removes.

## Ledger

`assets/ticket-distributions.tsv`, tab-separated, one row per ticket written
or undone:

```
date        distribution       template      project    file                     sha256  status
2026-11-02  D-20261102-142530  readme.md     soren-ds   issues/117-check-...md   9f2...  written
```

## Exit status

| Code | Meaning |
|------|---------|
| 0 | every chosen project got (or would get) the ticket; every ticket was (or would be) undone |
| 1 | at least one project was skipped, or one ticket was kept on undo; each line says why |
| 2 | a usage error, no project matched, or the ledger has nothing for that distribution |

## Tests

`test-distribute-ticket.sh [--dir MONOREPO]` builds a scratch monorepo in a
RAM folder and checks the dry run, both phase modes, the keyword layering,
the fail mode, writing, the re-run guard, `--create-issues`, the ledger and
undo. Its ledger is in the scratch folder; the real one is never touched.
