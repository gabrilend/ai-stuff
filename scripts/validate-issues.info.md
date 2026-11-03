# validate-issues

Checks a project's issue files against the house rules and against each other,
and says which issue number to use next in each phase.

## What it is for

Issue files are the blueprint of a project, and nothing used to check them. A
missing "Current Behavior" section, two files claiming the same number, or a
dependency written down in one file and forgotten in the other all went
unnoticed until someone planned against the wrong picture. This tool reads the
whole issues/ tree and reports every such place, one line each.

It reads names through the same shared reader as `progress-dashboard.lua`
(`libs/issue-names.lua`), so the two tools always agree about which phase an
issue belongs to.

## Commands

    validate-issues [DIR]
        Check the whole project (DIR defaults to the scripts project). Prints
        one line per finding, then a count and the next free id per phase.

    validate-issues [DIR] --next PHASE
        Print only the next free id in PHASE, in the project's own shape
        (522, 9-014, A08). Use this when creating an issue. A phase with no
        issues yet starts at 1.

    validate-issues [DIR] --file PATH
        Check one issue file: its name, its sections, and every link that
        touches it. Use this after writing or editing an issue.

    validate-issues [DIR] --completed
        Also check the sections of completed issues. Off by default because a
        completed issue is immutable history: a finding there cannot be fixed.

Exit status: 0 no findings, 1 findings printed, 2 bad arguments or no issues/.

## What counts as a finding

| Check | Finding |
|---|---|
| name | no `.md` extension; description not lower-case words joined by dashes |
| sections | an open issue lacks a heading containing "Current Behavior", "Intended Behavior" or "Implementation Steps" |
| duplicates | two open or completed files with the same id (a superseded file keeping an old id is not counted, nor is a pointer file) |
| orphans | a sub-issue (104a) with no parent (104) |
| dangling links | a link field names an id with no file |
| one-sided links | A says it blocks B but B does not name A as a blocker, or the reverse; checked only when the project writes links in both directions |

A **pointer file** is what an issue renumbered to a free id leaves at its
old path, so that old links still lead somewhere: a top-level title that
says it moved ("# Moved: Issue 515 is now Issue 543", or "... has moved"),
a link to another `.md` file, at most 24 lines, and none of an issue's
sections. It keeps its id (links to it aren't dangling, and `--next` won't
hand the id out again), but it isn't counted as a duplicate, its sections
aren't checked, and its links assert nothing.

Link fields are read under the labels "Blocked by", "Blocks", "Dependencies"
and "Depends on", in four shapes: a header-table row, a bold label, a bold
bullet, or a `##` heading whose body runs to the next heading. A number is only
taken as an issue reference when it names a phase the project has issues in,
so years and percentages in free text are not mistaken for links. Links written
in superseded or declined files are ignored.

## Relationship to other tools

- `progress-dashboard.lua` — counts the same issues by phase.
- `validate-issue-graph` in enheim-tome — the ancestor of the link check; it
  also has a `--fix` that writes the union of both sides into both files. This
  tool reports only and never edits an issue file.
- The `issue-lifecycle` skill (`~/.claude/skills/issue-lifecycle/`) runs this
  tool when an issue is created, edited, or completed.
