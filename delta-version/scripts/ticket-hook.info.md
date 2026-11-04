# ticket, ticket-hook.sh, install-ticket-hook.sh

Issue 022: one name for the ticket tools, and an opt-in post-commit hook.

## `ticket`

`ticket` only hands each command to the tool that does the work:

| Command | Runs |
|---------|------|
| `ticket file TEMPLATE --phase=… TARGETS [--write]` | `distribute-ticket.lua` (dry run unless `--write`) |
| `ticket menu` | `ticket-menu.sh` |
| `ticket check TEMPLATE` / `ticket keywords` | `process-template.lua --check` / `--list` |
| `ticket history` | one line per distribution in the ledger |
| `ticket undo D-… [--write]` | `distribute-ticket.lua --undo` |
| `ticket hook install / uninstall / status` | `install-ticket-hook.sh` |
| `ticket hook preview [--commit REV]` / `ticket hook check` | `ticket-hook.sh` |
| `ticket test` | `test-ticket-chain.sh` |

`DIR` names the monorepo (default `/mnt/mtwo/programming/ai-stuff`).

## The hook

The hook is opt-in twice over.

1. **Nothing installs it but you.** `install-ticket-hook.sh [--repo PATH]`
   (or `ticket hook install`) writes a short `post-commit` hook that calls
   `ticket-hook.sh`. It goes wherever git looks for hooks, `core.hooksPath`
   included.
   - It never replaces a hook it did not write. If another `post-commit`
     hook is there, it refuses and prints the line to add to that hook.
   - `--uninstall` removes only its own hook.
2. **It only previews until you say otherwise.** When a commit adds or
   changes a file in `delta-version/templates/tickets/`, the hook looks the
   template up in `config/ticket-hooks.conf`. It runs `distribute-ticket.lua`
   as a dry run for that template's targets, then prints the exact command
   that would file the tickets. It writes only when the configuration says
   `write = on`, and the file ships with `write = off`.

The hook never stops a commit: a post-commit hook runs after the commit is
made, and `ticket-hook.sh` exits 0 when run as the hook. A template with no
line in the configuration is named and left alone. Removing a template
previews nothing.

## `config/ticket-hooks.conf`

```
write = off
# ledger = /path/to/ledger.tsv
readme-run-instructions.md = --phase=current --language=lua,c
```

Rules for a template line:
- **The name** is a file name in `templates/tickets/`, not a path.
- **Allowed options:** `--projects`, `--profile`, `--language`, `--uses`,
  `--state`, `--has`, `--active-days`, `--only`, `--exclude`, `--phase`,
  `--slug`, `--error-mode`, `--create-issues`. `--phase=` is required.
- **Values** may hold only letters, digits and `, . _ -`.
- **The hook alone decides** `--write`, `--dir`, `--ledger`, `--again` and
  `--undo`. A line that tries to set one of them is refused, and so is a
  value with shell characters.
- **Checking:** `ticket hook check` reports every bad line and exits 1 if
  there is one.

## Tests

`test-ticket-hook.sh [--dir MONOREPO]` installs the hook into a scratch
monorepo in RAM and makes real commits there. It checks:
- the preview, and that running the printed command files the ticket;
- `write = on`, a template with no targets, a removed template, and that a
  bad configuration still lets the commit through;
- refusing someone else's hook, and every `ticket` command.

It is also one of the parts `test-ticket-chain.sh` runs.
