# 205 — The summary view

The viewing side of the survey: built from the two tables alone
([004](../docs/004-datapath-the-survey.md), *the summary*).

## Current Behavior

The tables exist; nothing reads them for a person.

## Intended Behavior

A module separate from every survey-generating module, which reads
`files.tsv` and `links.tsv` and writes `survey/summary.txt`:

- counts of files, lines and bytes by language and by role;
- the ten largest code files;
- the ten files most linked to from inside (likely foundations);
- the files that link to others but nothing links to (likely entry points);
- every outside dependency by name, with how many files use it.

Command `summary` rebuilds it and prints it. `survey` writes it at the end.

## Suggested Implementation Steps

1. The summary. **Test:** on a fixture survey, every section's numbers match
   hand counts.
2. **Test:** deleting `summary.txt` and running `summary` makes it again
   without walking the source (the source path can be missing).

## Blocked by

- 204
