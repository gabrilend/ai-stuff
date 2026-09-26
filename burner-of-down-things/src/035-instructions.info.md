# 035-instructions.lua

Assembles a turn's standing instructions: rules for its kind (no questions,
no commands, what it may read and write, and for build and repair that the
source does not exist for them), the crafts (skill files) its kind names plus
— for build and repair — those listed in the case's `input/crafts`, and the
center's paragraph.

| Function | In | Out |
|---|---|---|
| `write(turn, case, skills_folder, center_paragraph)` | turn table; case table; folder of skill folders; text or "" | writes `instructions.md`; returns the text. Refuses a missing craft file, and text over `LIMIT` (120 KiB; one command-line argument holds 128 KiB) |
| `person_crafts(case)` | case table | array of skill names from `input/crafts` (blank and `#` lines skipped) |
