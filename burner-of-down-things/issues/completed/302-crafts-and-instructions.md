# 302 — Crafts and instructions

The standing instructions each turn is handed: the machine's rules for that
kind, the owner's skill files it names, and (from phase 7) the center's
paragraph ([005](../docs/005-datapath-the-hands.md), *crafts*).

## Current Behavior

Built as `src/035-instructions.lua`. Build and repair turns take their crafts from the case's `input/crafts` (one skill name per line) rather than from a fixed list: the person decides which of their skills a design is built with. Instructions over 120 KiB are refused, since Claude Code receives them as one argument. Checked by tests/040.

## Intended Behavior

- **Rules text** per kind, held in the source beside the kinds table: that
  this is one turn of a machine; what it may read and write (from the
  confinement, as paths); that it must not ask questions (nobody is there to
  answer); that it must not commit, run commands, or touch anything else; for
  build kinds, that the source does not exist for it.
- **Crafts:** for each skill name in the kind's row, the file
  `<skills folder>/<name>/SKILL.md` is read whole and placed under a heading.
  The skills folder is a setting, default `~/.claude/skills`.
- A slot for the center's paragraph, empty until phase 7 fills it.
- Written to the turn's `instructions.md`.

| Decision | What each path leads to |
|---|---|
| A named craft's file is missing | The turn is refused before it starts, naming the file |

## Suggested Implementation Steps

1. Rules and assembly. **Test:** a describe turn's instructions contain the
   issue-lifecycle skill text and its write path; a build turn's contain no
   source path anywhere.
2. **Test:** a skills folder without the named skill refuses.

## Blocked by

- 301
