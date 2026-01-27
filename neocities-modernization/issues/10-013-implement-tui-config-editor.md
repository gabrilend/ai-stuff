# Issue 10-013: Interactive TUI Config Editor

## Priority
Medium

## Current Behavior

The project's unified configuration (`config.lua`) can only be edited by hand-editing the Lua source file. This presents several usability problems:

1. **Syntax risk**: A misplaced comma or missing quote breaks the entire pipeline — Lua parse errors give cryptic line numbers that don't clearly indicate the problem
2. **Discoverability**: New users (and future-you) must read the file to know what's configurable — there's no guided walkthrough of available settings
3. **Excluded poems workflow**: Adding poems to `excluded_poems` requires knowing the exact ID format per category, finding the right array in the file, and inserting with correct Lua syntax
4. **No validation**: Nothing prevents setting `poems_per_page = -5` or `default_algorithm = "bogus"` until the pipeline crashes at runtime
5. **Context switching**: Must leave the TUI pipeline runner (`run.sh -I`) to edit config, then re-enter — breaks the interactive workflow

The existing TUI infrastructure (`lua-menu.sh` + `menu.lua`) already provides a polished interactive experience for the pipeline runner but is not used for configuration management.

## Intended Behavior

A new script (`scripts/edit-config`) launches an interactive TUI for editing `config.lua`, with sections mirroring each configuration category. Changes are validated and written back to the Lua source file.

### Launch

```bash
# Standalone
./scripts/edit-config

# Or from the pipeline TUI as an action button
# (future enhancement — see Future Enhancements section)
```

### TUI Layout

The editor presents a single menu with sections for each `config.lua` category, using the same `lua-menu.sh` library and visual style as `run.sh -I`:

```
╔══════════════════════════════════════════════════╗
║  Neocities Config Editor                         ║
║  Use j/k to navigate, Enter to toggle/edit       ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  ── Extraction ──────────────────────────────    ║
║  [x] Enable fediverse                            ║
║  [x] Enable messages                             ║
║  [x] Enable notes                                ║
║  [x] Enable bluesky                              ║
║                                                  ║
║  ── Excluded Poems ──────────────────────────    ║
║  fediverse: (0 excluded)         [+ Add]         ║
║  notes: (0 excluded)             [+ Add]         ║
║  messages: (0 excluded)          [+ Add]         ║
║  bluesky: (0 excluded)           [+ Add]         ║
║                                                  ║
║  ── Privacy ─────────────────────────────────    ║
║  Mode: [clean / raw]                             ║
║  [x] Include boosts                              ║
║  [x] Preserve original length                    ║
║  Local server domain: ____tech.lgbt____          ║
║                                                  ║
║  ── Pagination ──────────────────────────────    ║
║  Poems per page:           [  200 ]              ║
║  Max pages per poem:       [   15 ]              ║
║  Chronological per page:   [  500 ]              ║
║  [x] Generate TXT exports                        ║
║                                                  ║
║  ── Layout ──────────────────────────────────    ║
║  Regular poem width:       [   83 ]              ║
║  Golden poem width:        [   85 ]              ║
║  Text content width:       [   80 ]              ║
║                                                  ║
║  ── Golden Poems ────────────────────────────    ║
║  [x] Enable golden prioritization                ║
║  Pair bonus:               [ 0.05 ]              ║
║  Single bonus:             [ 0.02 ]              ║
║                                                  ║
║  ── Similarity ──────────────────────────────    ║
║  Algorithm: [cosine / euclidean / angular]        ║
║                                                  ║
║  ── HTML Theme ──────────────────────────────    ║
║  Background:  ___#000000___                      ║
║  Text:        ___#FFFFFF___                      ║
║  Link:        ___#6699FF___                      ║
║  Visited:     ___#9966FF___                      ║
║                                                  ║
║  ── Storage ─────────────────────────────────    ║
║  Storage limit (GB):       [   45 ]              ║
║  Reserved for maze (GB):   [0.031 ]              ║
║  Reserved headroom (GB):   [    5 ]              ║
║                                                  ║
║  ── Actions ─────────────────────────────────    ║
║  [ Save Changes ]  [ Discard & Quit ]            ║
║                                                  ║
╚══════════════════════════════════════════════════╝
```

### Section Details

#### 1. Extraction (4 checkboxes)
Maps directly to `config.extraction.enable_*` booleans. Simple toggles.

#### 2. Excluded Poems (category-specific list management)
This is the most complex section. Each category shows:
- Current count of excluded IDs
- An `[+ Add]` action that prompts for an ID
- When expanded (Enter on category), lists all excluded IDs with `[x Remove]` option

**Add workflow**:
1. Select `[+ Add]` next to a category
2. TUI switches to text input mode
3. User types the ID (e.g., `113847291038475` for fediverse)
4. ID is added to the in-memory exclusion list
5. Count updates immediately

**Remove workflow**:
1. Select a category to expand its exclusion list
2. Each excluded ID is shown as a removable item
3. Toggle to mark for removal
4. Removal applied on save

**ID format hints** (shown in TUI description text):
| Category | Format | Example |
|----------|--------|---------|
| fediverse | Numeric ActivityPub post ID | `113847291038475` |
| notes | Filename without extension | `what-a-lame-movie` |
| messages | Zero-padded index | `0042` |
| bluesky | AT Protocol record key | `3k...abc` |

#### 3. Privacy (2 checkboxes, 1 multistate, 1 flag)
- `mode`: Multistate cycling between `clean` and `raw`
- `include_boosts`: Checkbox
- `preserve_original_length`: Checkbox
- `local_server_domain`: Text flag field

#### 4. Pagination (4 flags, 1 checkbox)
- `poems_per_page`: Numeric flag
- `max_pages_per_poem`: Numeric flag
- `chronological_poems_per_page`: Numeric flag
- `page_number_padding`: Numeric flag
- `generate_txt_exports`: Checkbox

#### 5. Layout (7 numeric flags)
All integer values controlling box-drawing dimensions. Display as editable numeric fields.

#### 6. Golden Poems (1 checkbox, 5 numeric flags)
- `enable_golden_prioritization`: Checkbox
- Remaining: Numeric flags with decimal precision

#### 7. Similarity (1 multistate)
Cycles between: `cosine`, `euclidean`, `manhattan`, `angular`, `pearson_correlation`

#### 8. HTML Theme (4 text flags)
Hex color strings. Display as editable text fields.

#### 9. Storage (3 numeric flags)
Numeric values with decimal precision for GB amounts.

#### 10. Actions
- **Save Changes**: Validates all values, writes to `config.lua`, exits
- **Discard & Quit**: Exits without saving (confirms if changes were made)

### Sections Excluded from TUI

These sections are too complex for a flat menu and are better edited by hand. The TUI should display them as read-only informational items:

- **`input_sources`**: Rarely changed paths — editing requires understanding the backup directory structure
- **`image_integration`** / **`image_sync`**: Complex nested source arrays with multiple fields per entry
- **`word_cloud.stop_words`**: 200+ word list — better managed as a text file or by hand
- **`centroids`**: Deeply nested keyword arrays with source files — requires creative judgment
- **`semantic_colors`**: Color palette design requires visual context, not a TUI

For these, the TUI should show a read-only summary line like:
```
  Input sources: 5 configured (edit config.lua directly)
  Centroids: 8 mood anchors (edit config.lua directly)
  Word cloud: 200 max words, 287 stop words (edit config.lua directly)
```

### Config Writer

The writer must produce valid, human-readable Lua that preserves:
1. **Vimfold markers** (`-- {{{` and `-- }}}`) around each section
2. **Comments** explaining each setting (the current documentation comments)
3. **Formatting** consistent with the existing style (4-space indent, aligned values)
4. **Section ordering** matching the current file layout

**Implementation approach**: Rather than generating the entire file from scratch (which would lose comments), use a targeted replacement strategy:
- Parse the current `config.lua` to identify section boundaries
- For each modified section, regenerate only that section's content
- Preserve all comments and vimfold structure
- Write the reconstructed file atomically (write to tmp, then rename)

### Validation Rules

Before saving, validate:
- Numeric fields are valid numbers within reasonable ranges
- `poems_per_page` > 0
- `max_pages_per_poem` >= 1
- Color hex strings match `#[0-9A-Fa-f]{6}`
- `similarity.default_algorithm` is one of the known algorithms
- `privacy.mode` is `clean` or `raw`
- Excluded poem IDs are non-empty strings
- Layout widths are positive integers

On validation failure, highlight the offending field in red and display the error message.

## Technical Design

### Script Structure

```
scripts/edit-config          -- Bash launcher (sources lua-menu.sh)
src/config-editor.lua        -- Core editor logic (reads/writes config.lua)
```

### Bash Launcher (`scripts/edit-config`)

```bash
#!/usr/bin/env bash
# Config editor TUI for neocities-modernization
# Launches an interactive menu for editing config.lua settings.
# Uses the same lua-menu.sh TUI library as run.sh.

DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"

# Source TUI library
source "${LIBS_DIR}/lua-menu.sh"

# Load current config values
eval "$(luajit "${DIR}/src/config-editor.lua" --export-values "${DIR}")"

# Build menu sections from exported values
menu_init
menu_set_title "Neocities Config Editor" "j/k navigate | Enter toggle | Type to edit | q quit"

# ... section building code ...

menu_run

# On save action, pass values back to Lua writer
luajit "${DIR}/src/config-editor.lua" --write-config "${DIR}" \
    --values "$(menu_export_json)"
```

### Lua Editor Module (`src/config-editor.lua`)

Two modes:
1. **`--export-values`**: Reads `config.lua`, outputs bash variable assignments for menu pre-population
2. **`--write-config`**: Receives JSON values from TUI, validates, and writes updated `config.lua`

### Config File Writing Strategy

The writer reads the existing `config.lua` line by line and reconstructs it:

```lua
-- Pseudocode for targeted section replacement
for each line in config.lua:
    if line matches section_start_pattern then
        current_section = detected_section
        emit(line)  -- preserve the fold marker and comment
        emit(generate_section_content(current_section, new_values))
        skip_until_section_end()
    else
        emit(line)  -- preserve as-is (comments, structure)
    end
```

This preserves:
- All `-- {{{ section_name` and `-- }}}` markers
- Documentation comments within sections
- The overall file structure and ordering
- Any manually-added comments

## Suggested Implementation Steps

1. **Create the bash launcher script** (`scripts/edit-config`):
   - Source `lua-menu.sh`
   - Hard-code `DIR` with argument override
   - Add header comment explaining the script

2. **Create the Lua editor module** (`src/config-editor.lua`):
   - Implement `--export-values` mode: read config.lua via config-loader, output bash assignments
   - Implement `--write-config` mode: receive JSON, validate, write config.lua

3. **Build the Extraction section** (simplest — 4 checkboxes):
   - Add section with 4 checkbox items mapping to `extraction.enable_*`
   - Test round-trip: load → display → toggle → save → verify file

4. **Build the Excluded Poems section** (most important):
   - Display per-category counts
   - Implement add workflow (text input for ID)
   - Implement remove workflow (toggle existing IDs)
   - Test with sample fediverse and notes exclusions

5. **Build remaining simple sections** (Privacy, Pagination, Layout, Golden Poems, Similarity, Theme, Storage):
   - Map each config value to the appropriate TUI item type
   - Add validation for numeric ranges and string formats

6. **Add read-only summaries** for complex sections (input_sources, image_*, word_cloud, centroids, semantic_colors)

7. **Implement the config writer**:
   - Parse section boundaries in existing config.lua
   - Generate replacement content for modified sections only
   - Atomic write (tmp file + rename)
   - Verify round-trip: original → parse → write → parse → compare

8. **Add validation layer**:
   - Range checks for numeric values
   - Format checks for hex colors and algorithm names
   - Display errors inline in TUI

9. **Test the complete workflow**:
   - Launch editor, modify values across multiple sections, save
   - Run the pipeline to verify config changes take effect
   - Test edge cases: empty exclusion lists, boundary values, invalid input

10. **Add to run.sh as optional action** (future, not required for this issue):
    - Add "Edit Config" action button to the pipeline TUI
    - Launch config editor as sub-process, reload config on return

## Dependencies

- `lua-menu.sh` / `menu.lua` / `menu-runner.lua` TUI library (exists at `/home/ritz/programming/ai-stuff/scripts/libs/`)
- `libs/config-loader.lua` (exists — loads unified config)
- `libs/exclusion-filter.lua` (exists — uses the excluded_poems section)
- LuaJIT runtime

## Related Documents

- `config.lua` — The configuration file being edited
- `libs/config-loader.lua` — Config loading utility
- `libs/exclusion-filter.lua` — Exclusion filter (issue 6-031)
- `issues/completed/10-003-consolidate-config-files-into-single-source.md` — Config consolidation
- `issues/10-002-integrate-tui-into-generate-embeddings.md` — Prior TUI integration pattern
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` — TUI bash API
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` — TUI Lua engine

## Future Enhancements

- **Pipeline integration**: Add "Edit Config" action to `run.sh -I` TUI, launching the editor as a sub-process
- **Diff preview**: Before saving, show a diff of what will change in config.lua
- **Config profiles**: Save/load named configuration profiles (e.g., "full-build", "quick-test", "fediverse-only")
- **Undo history**: Track recent changes with ability to revert
- **Search in exclusions**: Search poems.json by content snippet to find IDs for exclusion
- **Bulk exclusion import**: Paste a list of IDs to exclude in batch

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 10 (Developer Tooling)
- **Estimated Complexity**: Medium-High
- **Dependencies**: TUI library, config-loader
- **Affects**: config.lua, developer workflow, pipeline configuration
