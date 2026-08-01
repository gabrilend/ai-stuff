# 010-survey-command.lua

The survey, as something a person runs. Reached through `./survey` in the
project root.

## Functions

| Function | Takes | Gives back |
|---|---|---|
| `run(project_directory, arguments)` | the project root, an array of command-line strings | an exit status, 0 or 1 |

Arguments: `--deep` to also open orders files and measure record arrays; any
other argument is taken as a Dominions folder, overriding `input/game`.

## Written for reading aloud

Linear, one save per line, one figure per line. No columns that only line up in
a fixed-width font, no information carried by position or colour, no box
drawing, and plural forms that a screen reader will not stumble over.

That is the accessibility rule from the architecture applied to a developer
tool, on purpose: the first surface anybody builds is the one whose habits
spread.

## What it prints

- one line per savegame: turn, version, nations played, and mods
- a line when a file disagrees with its folder about its own name — the
  standing check on the disguise module's padding rule
- a summary: how many saves, how many started, the turn range, and the
  distribution of versions
- with `--deep`: per orders file, the measured stride, record count, and the
  fraction of the file placed; then the distribution of strides, and a warning
  if more than one appears

More than one stride across the collection is worth understanding before
anything relies on a single number, and the command says so rather than
averaging them.

## Related

- `008-survey.lua` — where the figures come from
- `011-survey-main.lua` — the entry point, which exists because of how luajit
  handles arguments after `-e`
- [issue 107](../issues/107-the-survey.md)
