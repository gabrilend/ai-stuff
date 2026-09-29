# 1002b — Append-only write

The second piece of 1002.

## Current Behavior

Built. `src/085-the-lesson.lua`'s `append(path, one)` takes an
already-built lesson (`build`'s own shape, not raw fields — validation and
persistence stay separate) and appends it to `path` as one Markdown
section in a single append-mode write, making the folder first if needed;
never opens `path` for reading, never rewrites what is already there.
Checked by `tests/102-checking-append-only-lessons.lua`. No reader exists
yet — 1002d's own note already says it can take `append`'s file, parsed,
once that reader is built.

## Intended Behavior

Lessons are appended to `output/story/lessons.md`, one per turning point,
never rewritten — the same append-only discipline as the ledger (016).

## Suggested Implementation Steps

1. The atomic-append writer. Done: `085-the-lesson.lua`'s `append`.
   **Test:** lessons are appended, never rewritten — writing a second
   lesson leaves the first byte-for-byte unchanged. Done.

## Blocked by

- 1002a
