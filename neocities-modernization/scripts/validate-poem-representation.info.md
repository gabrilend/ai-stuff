# validate-poem-representation.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/validate-poem-representation: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
validate-poem-representation: Validates that all poems are represented in generated output

Post-generation validator to ensure complete coverage of the poem corpus in HTML output.
Checks that all poems have corresponding similar/different pages and appear in chronological.
Useful for detecting interrupted generation runs, configuration errors, or edge cases.

Usage:
  ./scripts/validate-poem-representation [OPTIONS]

Options:
  --output PATH      the built site to check (default: the project's output/)
  --poems PATH       the poem list (default: the project's assets/poems.json)
  --fix              Regenerate missing pages (not implemented yet)
  --quiet            Only output errors and summary
  --json             Output results as JSON
  --help             Show this help message

Exit codes:
  0 = All poems represented (PASS)
  1 = Missing poems detected (FAIL)
  2 = Configuration error (missing required files)
```

## Inside (local to the file)

### `parse_arguments(args)`
(No comment above it in the source.)

### `print_usage()`
(No comment above it in the source.)

### `read_json_file(path)`
(No comment above it in the source.)

### `file_exists(path)`
(No comment above it in the source.)

### `count_files(directory, pattern)`
(No comment above it in the source.)

### `get_existing_poem_indices(directory, prefix)`
(No comment above it in the source.)

### `validate(options)`
(No comment above it in the source.)

### `output_json(results)`
(No comment above it in the source.)

### `output_summary(results, options)`
(No comment above it in the source.)

### `main()`
(No comment above it in the source.)
