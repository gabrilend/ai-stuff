# fix-issue-links

Makes two issue files agree about a dependency when only one of them wrote it
down.

## What it is for

A dependency between two issues is one fact written in two places: the waiting
issue names its blocker ("Blocked by", "Depends on", "Dependencies"), and the
blocker names what waits on it ("Blocks"). `validate-issues` reports every pair
where only one side wrote it. This tool writes the missing side.

It takes the union and never removes anything: a link asserted on either side
is treated as true.

## Commands

    fix-issue-links [DIR]
        Preview. Prints one line per file saying what would be added and
        where; changes nothing. Exits 1 if there is anything to do.

    fix-issue-links [DIR] --write
        Makes the edits. Run validate-issues afterwards to confirm.

    fix-issue-links [DIR] --completed
        Also edits issues in issues/completed/. Off by default: completed
        issues are history.

DIR defaults to the scripts project, like validate-issues.

Exit status: 0 nothing to fix or all fixed, 1 edits previewed but not written,
2 bad arguments or the checker could not run.

## Where it writes

| The file already has... | The missing link goes... |
|---|---|
| a field for the same direction | onto the end of that field (a new `- id` line for a heading section) |
| only a field for the other direction | into a new field right after it, in the same shape: table row, bold label (with a blank line before it), bullet, or heading section |
| no link field | into a new `## Blocks` or `## Blocked by` section at the end of the file |

Why the shape matters: validate-issues reads a `## Dependencies` heading as
running until the next heading. A `- **Blocks**:` bullet placed inside that
body would be read back as more dependencies. So beside a heading section the
new field is a heading of its own.

## How it finds the work

It runs `validate-issues DIR` and reads two kinds of finding:

- `A: does not list B under Blocks, but B names it as a blocker`: add B to
  A's Blocks.
- `A: does not name B as a blocker, but B says it blocks this`: add B to A's
  blockers.

So it agrees with the checker by construction: whatever the checker counts as a
link, this tool counts the same way.

## Test

`tests/test-fix-issue-links.sh` builds a pretend project with every link shape,
runs the tool, and checks that the checker finds no one-sided link left, that
each shape was written where the table above says, that completed issues were
left alone, and that a second run finds nothing to do.

## Relationship to other tools

- `validate-issues`: finds the one-sided links; this tool fixes them.
- `validate-issue-graph` in enheim-tome: an older tool with the same `--fix`
  idea, which only understands that project's header-table layout.
