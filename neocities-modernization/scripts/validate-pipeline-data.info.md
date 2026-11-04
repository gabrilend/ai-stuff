# validate-pipeline-data.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/validate-pipeline-data: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
validate-pipeline-data

Pipeline Data Validation Utility for Neocities Modernization Project
Checks completion status of embeddings, similarity matrix, diversity cache,
and HTML output to determine pipeline readiness for deployment.

Usage:
  ./scripts/validate-pipeline-data [OPTIONS]

Options:
  --quick                 Machine-readable output (fast, <1 second)
  --check-freshness      Validate timestamps and detect stale data
  --list-missing         Show specific poem IDs missing from matrix/cache
  --suggest-commands     Output exact commands to fix issues
  --format=json          Export structured JSON data
  --skip-validation      (Used by other scripts to bypass this check)
  --model=NAME           Embedding model to validate (default: embeddinggemma_latest)
  --help                 Show this help message

Exit codes:
  0 = Ready for deployment (all data complete and fresh)
  1 = Incomplete (missing data, can be fixed)
  2 = Stale (data exists but outdated)
  3 = Configuration error (missing required files/directories)

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `_cache_q()`

```
Issue 10-054: caches are switch-aware -- movable ones live in RAM (tmp/),
diversity stays on disk. Ask the central utils functions where they actually
are (this also resolves the real selected model, fixing the stale default).
```

### `count_poems()`
(No comment above it in the source.)

### `count_embeddings()`
(No comment above it in the source.)

### `count_similarity_rankings()`
(No comment above it in the source.)

### `check_diversity_cache()`
(No comment above it in the source.)

### `count_html_similar()`
(No comment above it in the source.)

### `count_html_different()`
(No comment above it in the source.)

### `check_chronological()`
(No comment above it in the source.)

### `get_file_mtime()`
(No comment above it in the source.)

### `format_timestamp()`
(No comment above it in the source.)

### `calculate_percentage()`
(No comment above it in the source.)

### `validate_pipeline()`
(No comment above it in the source.)

### `output_quick()`
(No comment above it in the source.)

### `output_human()`
(No comment above it in the source.)

### `list_missing_entries()`
(No comment above it in the source.)

### `suggest_commands()`
(No comment above it in the source.)

### `check_freshness()`
(No comment above it in the source.)

### `output_json()`
(No comment above it in the source.)
