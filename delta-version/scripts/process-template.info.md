# process-template.lua

Fills a ticket template's `][keyword[]` placeholders with facts about a
project and prints the filled ticket. The command line around
`libs/kml.lua`, the Keyword Markup Language engine (issue 017). Language:
`docs/keyword-markup-language-spec.md`. Keywords:
`config/ticket-keywords.conf`.

## Usage

    process-template.lua <template> [project-dir] [options]

| option | meaning |
| --- | --- |
| `project-dir` | where the commands run (default: the current folder) |
| `--config=FILE` | use this keyword file alone |
| `--error-mode=MODE` | `placeholder`, `remove`, `verbose` or `fail` |
| `--timeout=SECONDS` | per command |
| `--ticket-id=ID` | the value of `][ticket_id[]` |
| `--output=FILE` | write the ticket here instead of standard output |
| `--check` | run nothing; list each placeholder as `ok` or `bad` with the reason; exit 1 if any is bad |
| `--list` | list the configured keywords with their parameter slots |
| `--dir=PATH` | the delta-version folder (default `/mnt/mtwo/programming/ai-stuff/delta-version`) |

Without `--config`, delta-version's `config/ticket-keywords.conf` is read and
the project's own `config/ticket-keywords.conf`, if it has one, is layered
over it: a project adds or replaces keywords without copying the rest.

Exit 0 when the ticket was written (a failed keyword is marked as the error
mode says), 1 when the mode is `fail` and something failed, `--check` found a
problem, or a file could not be read or written; 2 for bad arguments. Every
failure is also named on standard error, one line each.

## Example

A template `report.md`:

    # Project Report: ][project_name[]
    Branch: ][git_branch[]
    - Lua files mentioning main: ][function_usage[main,lua][]

filled with `process-template.lua report.md ../words-pdf` gives the same
three lines with `words-pdf`, its branch, and the count in place of the
placeholders.

## Tests

`test-process-template.sh [monorepo]` (39 checks).
