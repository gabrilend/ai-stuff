# ticket-menu.sh

## Overview

The menu front end of ticket distribution (issue 020). You pick a template,
tick the projects and set the phase, then preview or distribute.
`distribute-ticket.lua` does every step; the menu only builds its command
line, and asks before anything is written.

The screen is the shared Lua menu (`scripts/libs/lua-menu.sh`), with its
usual keys: `j`/`k` to move, space to tick, `` ` `` or `x` to jump to Go,
`q` to quit.

```
ticket-menu.sh [--dir MONOREPO] [--templates FOLDER] [--ledger FILE]
```

## The menu

| Section | What it holds |
|---------|---------------|
| Template | each `*.md` in `delta-version/templates/tickets/`; the preview panel shows the highlighted one |
| Projects | every project `discover-projects.lua` lists, none ticked to begin with |
| Filing | Phase (0 = each project's current phase, or a number), Give projects issues/ (`--create-issues`), File again (`--again`) |
| Do | Preview, Distribute, History, Undo last |
| Run | Go |

After each step, Enter goes back to the menu with your choices kept, and `q`
quits.

## The steps

- **Preview** runs the dry run: each project, the file it would get, or why it
  is skipped.
- **Distribute** runs the same dry run, then asks `Write these tickets? [y/N]`.
  Only `y` or `yes` writes. Anything else, including no answer, writes
  nothing.
- **History** prints one line per distribution in the ledger: its id, date,
  template, and how many tickets it wrote and how many were undone.
- **Undo last** takes the newest distribution that still has tickets in place
  and runs `--undo` as a dry run. Then it asks `Remove these tickets? [y/N]`.
  As with the command line, only tickets still exactly as written are
  removed.

## Templates

A template is a Markdown file using the keyword markup language
(`docs/keyword-markup-language-spec.md`). To add one, put a `.md` file in
`templates/tickets/`. The menu has no editor of its own: your editor is
better at it. `readme-run-instructions.md` there is a working example.

For the command-line route (lettered phases, profiles, language filters),
use `distribute-ticket.lua` directly; see `distribute-ticket.info.md`.

## Tests

`test-ticket-menu.sh [--dir MONOREPO]` loads the menu's functions without
opening the screen and builds the menu from a scratch monorepo in RAM. It
sets the values a person would tick, then checks the command line, the
preview, the yes/no before writing and removing, the history and the undo.
The screen itself is the shared library's and has its own tests.
