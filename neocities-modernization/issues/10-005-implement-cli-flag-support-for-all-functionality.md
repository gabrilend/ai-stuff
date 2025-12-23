# 10-005: Implement CLI Flag Support for All Functionality

## Status
- **Phase**: 10
- **Priority**: High
- **Type**: Enhancement
- **Status**: COMPLETED
- **Created**: 2025-12-23
- **Completed**: 2025-12-23

## Current Behavior

~~The `run.sh` script has minimal CLI support.~~

**IMPLEMENTED**: Full CLI flag support with 7 pipeline stages, configuration flags, and output control.

## Implemented Behavior

All pipeline functionality is now accessible via CLI flags:

```bash
./run.sh [FLAGS] [PROJECT_DIR]

Pipeline Stages (run in order, multiple can be specified):
  --update-words      Sync input files from words repository
  --extract           Extract content from backup archives
  --parse             Parse poems from JSON sources into poems.json
  --validate          Run poem validation
  --catalog-images    Catalog images from input directories
  --generate-html     Generate website HTML (chronological + similarity pages)
  --generate-index    Generate numeric similarity index
  --all               Run all stages (default when no stages specified)

Stage Configuration:
  --threads N         Thread count for parallel HTML generation (default: 4)
  --force             Force regeneration even if files are fresh

Output Control:
  --quiet             Suppress progress messages
  --verbose           Show detailed progress
  --dry-run           Show what would be executed without running

Interactive Mode:
  -I, --interactive   Launch TUI for interactive selection

Directory Options:
  --dir PATH          Assets directory (where poems.json etc. are stored)
  --output PATH       Output directory (default: output/)

Other:
  -h, --help          Show this help message
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

Running `./run.sh` without stage flags runs all stages (backward compatible).

## Implementation Details (2025-12-23)

### Files Modified

1. **`run.sh`** - Complete rewrite with:
   - `show_help()` function with comprehensive usage docs
   - Stage boolean flags: UPDATE_WORDS, EXTRACT, PARSE, VALIDATE, CATALOG_IMAGES, GENERATE_HTML, GENERATE_INDEX
   - Config flags: THREADS, FORCE, QUIET, VERBOSE, DRY_RUN
   - `STAGE_FLAG_SET` tracking for backward compatibility
   - VimFold-organized stage execution functions:
     - `run_update_words()`
     - `run_extract()`
     - `run_parse()`
     - `run_validate()`
     - `run_catalog_images()`
     - `run_generate_html()`
     - `run_generate_index()`
   - Logging functions: `log_info()`, `log_verbose()`, `log_stage()`, `log_dry_run()`
   - Pipeline order execution (stages always run in correct order)

2. **`libs/utils.lua`** - Added `parse_cli_args()` function:
   - Returns options table with all parsed CLI flags
   - Supports: `--parse-only`, `--validate-only`, `--catalog-only`, `--html-only`
   - Supports: `--force`, `--threads N`
   - Backward compatible with existing `parse_interactive_args()`

3. **`src/main.lua`** - Updated `M.main()`:
   - Now accepts options table instead of boolean
   - Handles stage-specific flags for selective execution
   - Passes `force` option through to relevant functions

### Implementation Steps Completed

1. [x] Add flag parsing for all pipeline stages using while loop
2. [x] Create stage execution functions that can be called independently
3. [x] Implement execution order logic (boolean flags checked in order)
4. [x] Add `--all` flag that sets all stage flags
5. [x] Add `--threads`, `--force`, `--quiet`, `--verbose`, `--dry-run` flags
6. [x] Update existing `-I` handling to work with new flag system
7. [x] Pass relevant flags through to Lua scripts
8. [x] Add `--help` flag with comprehensive usage documentation
9. [x] Test all flag combinations
10. [x] Stage flags pass through to main.lua (`--parse-only`, etc.)

### Testing Verification

```bash
# Help flag
./run.sh --help                    # ✓ Shows comprehensive usage

# Dry-run all stages
./run.sh --all --dry-run           # ✓ Shows all 7 stages with commands

# Selective stages
./run.sh --validate --generate-html --dry-run  # ✓ Shows only stages 4 and 6

# Invalid flag handling
./run.sh --invalid-flag            # ✓ Shows error and help hint

# Actual stage execution
./run.sh --validate --quiet        # ✓ Runs validation only
```

## Related Documents

- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/run.sh` (implemented)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/libs/utils.lua` (modified)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/src/main.lua` (modified)
- Issue 10-004: Command preview (can now be implemented - depends on this)
- Issue 10-006: Checkbox conversions (can now map to these flags)

---
