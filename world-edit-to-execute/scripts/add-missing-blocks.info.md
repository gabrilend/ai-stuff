# add-missing-blocks.lua

Writes the "Blocks" entries that issue files are missing. When issue B says
it depends on issue A, A should say it blocks B; the issue validator
(`/home/ritz/programming/ai-stuff/scripts/validate-issues`) reports every
place only one side says so. This tool reads that report and adds the
missing names to A's "Blocks" line.

## Using it

```bash
report=$(/home/ritz/programming/ai-stuff/scripts/validate-issues /mnt/mtwo/programming/ai-stuff/world-edit-to-execute)
luajit scripts/add-missing-blocks.lua [DIR] [--dry-run] <<< "$report"
```

| Argument | Type | Meaning |
|----------|------|---------|
| `DIR` | path | the project folder; defaults to this project |
| `--dry-run` | flag | print what would be added, change nothing |
| standard input | text | the validator's report; only its "does not list X under Blocks" lines are read |

## What it changes

- A file with a `**Blocks:**` line: the missing ids are appended to it.
- A file with no `**Blocks:**` line but a `**Dependencies:**`,
  `**Depends on:**` or `**Blocked by:**` line: a new `**Blocks:**` line is
  added under it.
- It only adds. It never removes or rewrites a link, so a completed issue
  gains a line and loses nothing.

## What it leaves for a person

Printed at the end, with the reason, and the exit status is 1 when there
are any:
- files in `issues/archive/` or `issues/superseded/`: a live issue naming a
  retired one is fixed on the live side, not by giving the retired issue a
  new line;
- files with neither a Blocks nor a dependency line in their header.

## Output

One line per changed file (`added to <file>: <ids>`), then a count of
files changed and the list of files left for a person.
