# 10-005: Implement CLI Flag Support for All Functionality

## Status
- **Phase**: 10
- **Priority**: High
- **Type**: Enhancement
- **Status**: Open
- **Created**: 2025-12-23

## Current Behavior

The `run.sh` script has minimal CLI support:

```bash
./run.sh [-I] [--dir PATH] [PROJECT_DIR]
```

Current flags:
- `-I`: Enable interactive mode (launches TUI)
- `--dir PATH`: Specify assets directory
- Positional: Project directory (defaults to hard-coded path)

The script always runs the full pipeline:
1. `scripts/update-words` - Sync input files
2. `scripts/update` - Extract content from archives
3. `src/main.lua` - Run main pipeline (extraction, validation, images, HTML)
4. `scripts/generate-numeric-index` - Generate numeric index

Users cannot selectively run stages or skip stages from the command line.

## Intended Behavior

All pipeline functionality should be accessible via CLI flags:

```bash
./run.sh [FLAGS] [PROJECT_DIR]

Pipeline Stages (run in order, multiple can be specified):
  --update-words      Sync input files from words repository
  --extract           Extract content from backup archives
  --validate          Run poem validation only
  --catalog-images    Catalog images only
  --generate-html     Generate website HTML
  --generate-index    Generate numeric similarity index
  --all               Run all stages (default behavior)

Stage Configuration:
  --threads N         Thread count for parallel operations
  --force             Force regeneration even if files are fresh

Output Control:
  --quiet             Suppress progress messages
  --verbose           Show detailed progress
  --dry-run           Show what would be done without executing

Interactive Mode:
  -I, --interactive   Launch TUI for interactive selection

Directory Options:
  --dir PATH          Assets directory
  --output PATH       Output directory (default: output/)
```

### Execution Order

When multiple stage flags are specified, they execute in pipeline order regardless of argument order:

```bash
# These are equivalent:
./run.sh --generate-html --validate --extract
./run.sh --extract --validate --generate-html
```

Both execute: extract → validate → generate-html

### Default Behavior

Running `./run.sh` without stage flags should:
- Continue running all stages (backward compatible)
- Equivalent to `./run.sh --all`

## Implementation Steps

1. [ ] Add flag parsing for all pipeline stages using getopts or while loop
2. [ ] Create stage execution functions that can be called independently:
   - `run_update_words()`
   - `run_extract()`
   - `run_validate()`
   - `run_catalog_images()`
   - `run_generate_html()`
   - `run_generate_index()`
3. [ ] Implement execution order logic (sort flags by pipeline order)
4. [ ] Add `--all` flag that sets all stage flags
5. [ ] Add `--threads`, `--force`, `--quiet`, `--verbose`, `--dry-run` flags
6. [ ] Update existing `-I` handling to work with new flag system
7. [ ] Pass relevant flags through to Lua scripts (e.g., `--threads` to parallel generator)
8. [ ] Add `--help` flag with comprehensive usage documentation
9. [ ] Test all flag combinations
10. [ ] Update any documentation referencing run.sh usage

## Example Usage After Implementation

```bash
# Full pipeline (default)
./run.sh

# Just regenerate HTML
./run.sh --generate-html

# Extract and validate only
./run.sh --extract --validate

# Generate HTML with 8 threads, force regeneration
./run.sh --generate-html --threads 8 --force

# Preview what would run
./run.sh --all --dry-run

# Interactive mode with pre-selected stages
./run.sh -I --generate-html --generate-index
```

## Technical Notes

### Flag Parsing Pattern

Follow the existing pattern but expand:

```bash
# Stage flags (boolean)
UPDATE_WORDS=false
EXTRACT=false
VALIDATE=false
# ... etc

# Configuration flags
THREADS=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --update-words) UPDATE_WORDS=true; shift ;;
        --extract) EXTRACT=true; shift ;;
        --threads) THREADS="$2"; shift 2 ;;
        --all)
            UPDATE_WORDS=true
            EXTRACT=true
            # ... set all to true
            shift ;;
        # ... etc
    esac
done

# If no stage flags specified, run all (backward compatible)
if ! $UPDATE_WORDS && ! $EXTRACT && ! ... ; then
    UPDATE_WORDS=true
    EXTRACT=true
    # ... all true
fi
```

## Related Documents

- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/run.sh` (target script)
- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (reference for comprehensive flags)
- Issue 10-004: Command preview (depends on this issue)
- Issue 10-006: Checkbox conversions (UI representation of these flags)

---
