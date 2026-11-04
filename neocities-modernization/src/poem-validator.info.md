# poem-validator.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/poem-validator.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
poem-validator.lua: Stage 4's check of the poem list.

WHAT IT DOES (for a CEO): reads assets/poems.json and reports what is in
it -- how many poems, how many empty, duplicates, the spread of lengths,
the "golden" poems of exactly 1024 characters -- and writes the
validation report. main.lua --validate-only calls it in a build.

Usage: luajit src/poem-validator.lua [--dir PATH] [-I]
  --dir PATH project folder (default below); -I  ask before each step

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.validate_poems(poems_file, output_file)`
(No comment above it in the source.)

### `M.main(interactive_mode)`
(No comment above it in the source.)

## Inside (local to the file)

### `relative_path(absolute_path)`
(No comment above it in the source.)

### `generate_character_distribution_report(validation_stats)`
(No comment above it in the source.)

### `analyze_poem_content(poem)`
(No comment above it in the source.)

### `detect_duplicates(poems)`
(No comment above it in the source.)

### `generate_statistics(analyses)`
(No comment above it in the source.)
