# Phase 10 Progress Report

## Phase 10 Goals

**"Developer Experience & Tooling"**

Phase 10 focuses on improving the developer experience through enhanced tooling, unified configuration, and interactive interfaces.

### **From Phase 9**
- GPU acceleration infrastructure operational
- Pipeline running with automated stages
- Diversity and similarity computation working

### **Phase 10 Objectives**
- Consolidate configuration into single authoritative source
- Implement interactive TUI for pipeline management
- Add CLI flag support for all functionality
- Create pipeline data validation utilities
- Enhance developer workflow with better tooling

## Phase 10 Issues

### Active Issues

| Issue | Description | Status | Priority |
|-------|-------------|--------|----------|
| 10-001 | Integrate TUI into phase-demo.sh | Open | High |
| 10-002 | Integrate TUI into generate-embeddings | Open | Medium |
| 10-003 | Consolidate config files into single source (umbrella) | Completed | Medium |
| 10-008 | Implement multiline command wrapping | Completed | Low |
| 10-009 | Optimize incremental centroid updates for dataset expansion | Open | Medium |
| 10-010 | Integrate test suites into development pipeline | Open | Medium |
| 10-013 | Implement TUI config editor | Open | Medium |
| 10-018 | Animated command option transitions | Completed | Low |
| 10-019 | Document config structure and field usage | Open | Low |
| 10-022 | Fix empty embeddings validation | Completed | High |
| 10-023 | Fix image manager shell escaping and duplicates | Completed | Medium |
| 10-024 | Force flag should clear output directories | Completed | High |
| 10-025 | Diversity cache includes anchor poem | Completed | Medium |
| 10-026 | Merge sources and external_files config sections | Completed | Low |
| 10-027 | Fix golden poem trailing whitespace detection | Resolved (Mastodon limitation) | Medium |
| 10-028 | Lower pipeline process priority for UI responsiveness | Completed | Low |
| 10-029 | TUI Ollama server selector dropdown | Open | Medium |
| 10-030 | Image source position randomization | Completed | Low |
| 10-031 | Embedding model evaluation framework | Open | Medium |
| 10-032 | Fix shared flag prefix collision in TUI sync | Completed | High |
| 10-033 | Fix HTML generation memory exhaustion | Completed | Critical |
| 10-034 | Lazy loading orchestrator for parallel HTML | Completed | High |
| 10-035 | Parallelize word page generation | Open | Medium |
| 10-036 | Fix word page chronological links | Completed | Medium |
| 10-037 | Blank fediverse_boost content | Open | Medium |
| 10-038 | Separate ID numbering for fediverse_boost | Open | Low |
| 10-039 | Render external boost URLs as clickable links | Open | Low |
| 10-040 | Boost styling inconsistency across page types | Open | Medium |
| 10-041 | Malformed boost box alignment | Open | Medium |
| 10-042 | Integrate standalone images into site | Open | Medium |

### Completed Issues

| Issue | Description | Status | Completed |
|-------|-------------|--------|-----------|
| 10-003 | Consolidate config files into single source (umbrella) | Completed | 2026-01-30 |
| 10-003a | Initial config file consolidation | Completed | 2026-01-21 |
| 10-003b | External files syncing centralization | Completed | 2026-01-30 |
| 10-005 | Implement CLI flag support for all functionality | Completed | 2026-01-09 |
| 10-006 | Identify checkbox conversion opportunities | Completed | 2026-01-09 |
| 10-011 | Implement pipeline data validation utility | Completed | 2026-01-17 |
| 10-012 | Fix pipeline validation counting bugs | Completed | 2026-01-30 |
| 10-014 | Complete config migration from input-sources.json | Completed | 2026-01-30 |
| 10-015 | Unified input sources configuration | Completed | 2026-01-30 |
| 10-015a | Migrate image-manager to sources-loader | Completed | 2026-01-30 |
| 10-016 | TUI per-stage regeneration options | Completed | 2026-01-30 |
| 10-017 | Multi-Ollama server configuration | Completed | 2026-01-30 |
| 10-018 | Animated command option transitions | Completed | 2026-01-30 |
| 10-021 | Whitespace-preserving word wrap for poems | Completed | 2026-01-30 |
| 10-022 | Fix empty embeddings validation in GPU similarity | Completed | 2026-02-10 |
| 10-023 | Fix image manager shell escaping and duplicates | Completed | 2026-02-10 |
| 10-024 | Force flag should clear output directories | Completed | 2026-02-13 |
| 10-025 | Diversity cache includes anchor poem | Completed | 2026-02-13 |
| 10-026 | Merge sources and external_files config sections | Completed | 2026-02-18 |
| 10-008 | Implement multiline command wrapping | Completed | 2026-03-18 |
| 10-032 | Fix shared flag prefix collision in TUI sync | Completed | 2026-03-23 |
| 10-033 | Fix HTML generation memory exhaustion | Completed | 2026-03-23 |
| 10-034 | Lazy loading orchestrator for parallel HTML | Completed | 2026-03-23 |
| 10-036 | Fix word page chronological links | Completed | 2026-03-23 |

## Issue Details

**10-003: Consolidate Config Files** - COMPLETED (umbrella issue)
- Split into sub-issues for tracking:
  - 10-003a: Initial consolidation (COMPLETED 2026-01-21)
  - 10-003b: External files centralization (COMPLETED 2026-01-30)
- Related: 10-015 (Unified input sources) - also completed

**10-003a: Initial Config Consolidation** - COMPLETED (2026-01-21)
- Unified configuration into `config.lua`
- Migrated settings from 6+ separate files
- Added vimfolded sections for each config category
- Single authoritative source for all project settings

**10-003b: External Files Centralization** - COMPLETED (2026-01-30)
- Created `libs/external-sync.lua` module for unified external file syncing
- Created `scripts/sync-external-files` CLI wrapper
- Added `external_files` section to config.lua
- Replaced hardcoded paths in scripts/update and scripts/update-words
- Removed deprecated `image_sync` section

**10-014: Complete Config Migration** - COMPLETED (2026-01-30)
- Follow-up to 10-003: migrated remaining scripts still using `input-sources.json`
- `scripts/update-words`: Created Lua helper functions for bash config reading
- `scripts/generate-html-parallel`: Migrated to `dofile()` for pagination config
- `scripts/validate-poem-representation`: Migrated to `dofile()` for config loading
- Eliminates "Config file not found" warning during pipeline execution

**10-011: Pipeline Data Validation Utility** - COMPLETED (2026-01-17)
- Created `scripts/validate-pipeline-data` script
- Checks embeddings, similarity matrix, diversity cache completeness
- Quick mode and full validation modes
- Deployment readiness verification

**10-012: Fix Pipeline Validation Counting Bugs** - COMPLETED (2026-01-30)
- Fixed validator to use correct data sources (JSON files vs cache files)
- Added progress percentage displays
- Validated counts match actual poem collection

**10-013: TUI Config Editor** - OPEN
- Interactive editor for config.lua
- Validation before writing
- Integrates with existing TUI infrastructure

**10-015: Unified Input Sources Configuration** - COMPLETED (2026-01-30)
- Created `libs/sources-loader.lua` module for unified source config
- Consolidated input paths into single `sources` section in config.lua
- Supports multiple named directories per source type
- Migrated all extractors to use sources-loader (no fallbacks)
- Removed deprecated `input_sources` section (10-015a)

**10-015a: Migrate image-manager to sources-loader** - COMPLETED (2026-01-30)
- Updated `src/image-manager.lua` to use sources-loader
- Removed last dependency on `input_sources` section
- Follows "no fallbacks" design - errors clearly if config missing

**10-016: TUI Per-Stage Regeneration Options** - COMPLETED (2026-01-30)
- Moved "Force regenerate ALL stages" to top of stages section
- Added 10 indented "↳ Force regenerate" sub-options with visual indentation
- Per-stage options grayed out when global force is checked (via menu_add_dependency)
- Added CLI `--force-stage=N` flag (accepts 1-10)
- Updated stages 1, 3, 6, 7, 8, 9 to check both global and per-stage force flags
- Enables selective cache invalidation without full rebuild

**10-017: Multi-Ollama Server Configuration** - COMPLETED (2026-01-30)
- Added `ollama_servers` config section with name, host, port, model per server
- CLI `--ollama NAME`, `--model NAME`, and `--list-ollama` flags implemented
- Server validation at pipeline start (fails-fast if unreachable)
- Centralized config replaces scattered OLLAMA_HOST environment variables
- Migrated all 5 files using `OLLAMA_ENDPOINT` to new `build_host_url()` API
- TUI radio button selection deferred (CLI sufficient for current workflow)
- "No fallbacks" design: removed all backward-compatibility code

**10-018: Animated Command Option Transitions** - COMPLETED (2026-01-30)
- Visual animations when options are added/removed from command preview
- Insert: highlight color (cyan, bold) for ~400ms, then fade to normal
- Remove: change to red/bold, pause, then progressively close gap
- Progressive slide animation (gap shrinks over 12 frames, 80ms each)
- Queue system processes animations in order (no interruption)
- Non-blocking input via FFI select() with timeout
- Animation enable flag in state (configurable)
- Files modified: tui.lua (FFI input), menu.lua (animation system)

**10-019: Document Config Structure and Field Usage** - OPEN
- Add inline documentation to config.lua explaining field usage
- Create docs/config-reference.md with detailed section-by-section guide
- Focus on "when to use which fields" over basic descriptions
- Variable verbosity: heavy docs for complex sections (sources, external_files), light for simple ones
- Include examples of common customizations and validation errors

**10-021: Whitespace-Preserving Word Wrap** - COMPLETED (2026-01-30)
- Re-enabled 80-char word wrapping (disabled by 8-056) with new algorithm
- Added `wrap_preserving_indent()` to text-formatter.lua
- Preserves leading whitespace on continuation lines
- Long URLs broken at character boundaries when exceeding line width
- Artistic indentation and paragraph breaks maintained

**10-022: Fix Empty Embeddings Validation** - COMPLETED (2026-02-10)
- GPU similarity module crashed when embeddings.json had empty array (from failed generation)
- Added validation to check `#embeddings > 0` before accessing first element
- Error message includes termination_reason from metadata for diagnosis
- Also fixed generate-embeddings.sh division by zero in statistics calculation
- Files modified: vk_similarity.lua, generate-embeddings.sh

**10-023: Fix Image Manager Shell Escaping and Duplicates** - COMPLETED (2026-02-10)
- Fixed shell errors for filenames with single quotes (e.g., `Sant'Azraphel.png`)
- Added `shell_escape()` function: replaces `'` with `'\''`
- Applied to all 6 io.popen shell commands (stat, identify, md5sum, find)
- Added automatic duplicate resolution: keeps newest file by modification_time
- Changed duplicate reporting from warning to informational message
- Catalog now includes `resolved_duplicates` with kept/removed paths

**10-024: Force Flag Should Clear Output Directories** - COMPLETED (2026-02-13)
- When using `--force` for HTML generation, stale files with obsolete poem_index values remained
- After poem re-extraction changed poem_index assignments, old HTML files showed wrong content
- Added directory clearing in run.sh when `--force` or `--force-stage=9` is set
- Clears `output/similar/`, `output/different/`, `output/chronological/` before regenerating
- Force now means "start fresh" not just "ignore freshness checks"

**10-025: Diversity Cache Includes Anchor Poem** - COMPLETED (2026-02-13)
- Diversity pages showed anchor poem twice (as anchor AND as #1 in diversity ranking)
- Root cause: GPU algorithm initializes sequence[0] with starting poem (algorithmically correct)
- Fixed by filtering `source_poem_index` when reading from cache in both:
  - `M.generate_maximum_diversity_sequence()` (sequential processing)
  - `get_diversity_sequence()` (parallel processing)
- Design choice: Filter at display time rather than modify cache (no cache regeneration needed)

**10-026: Merge sources and external_files Config Sections** - COMPLETED (2026-02-18)
- Merged `external_files` into `sources` section for unified configuration
- Added `external = { source = "..." }` field to directory entries (7 entries)
- Added `archives = [...]` array for ZIP files (fediverse, messages)
- Extended sources-loader.lua with `get_all_external_syncs()` function
- Updated external-sync.lua to read from sources-loader first
- Deprecated `external_files` section (now empty, kept for reference)
- Fixed path inconsistency: fediverse-stars now points to correct sync destination
- All 9 external sync entries verified working through both loaders

**10-029: TUI Ollama Server Selector Dropdown** - OPEN
- Add dropdown selector to TUI for Ollama server selection
- Shows all servers from `ollama_servers` config section
- Updates command preview with `--ollama=NAME` flag
- Optional model dropdown filtered by server's `available_models`
- Depends on: scripts/issues/017 (TUI dropdown component)
- Builds on: 10-017 (Multi-Ollama server configuration)

**10-030: Image Source Position Randomization** - COMPLETED (2026-03-18)
- Add `randomize_order` config option to image source directories
- Scatters images throughout timeline instead of clustering by source
- Optional `random_seed` for reproducible randomization (LCG-based)
- Files modified: sources-loader.lua, image-manager.lua, config.lua
- Verified: 199 images randomized (dnd-pictures + fediverse-stars)

**10-008: Implement Multiline Command Wrapping** - COMPLETED (2026-03-18)
- Token-aware wrapping with backslash continuation
- Flag+argument pairs treated atomically (e.g., `--threads 4` never splits)
- Multi-line editing with position-mapped cursor navigation
- Per-token coloring preserved (yellow=radio/base, green=checkbox, cyan=other)
- Cursor restricted to editable area (cannot reach ./run.sh)
- Line-based navigation: j/k/UP/DOWN move between wrapped lines
- Line-specific $, 0: end/start of current line; G/gg: end/start of command
- Files modified: /home/ritz/programming/ai-stuff/scripts/libs/menu.lua

**10-031: Embedding Model Evaluation Framework** - OPEN
- Systematic comparison of embedding models (nomic, mxbai, etc.)
- Generate similarity rankings for test anchor poems across models
- Analyze model "personality" (semantic vs structural, verbs vs nouns)
- Output: comparison report, similarity matrices, model profiles
- Open questions: anchor selection, dimension interpretation, meta-models

**10-032: Fix Shared Flag Prefix Collision in TUI Sync** - COMPLETED (2026-03-23)
- Bug: Moving cursor from command preview deselected `--force-stage N` checkboxes
- Root cause: All `--force-stage N` flags share prefix `--force-stage`
- In `build_flag_lookup()`, the prefix key gets overwritten by each subsequent item
- When parsing command text, prefix `--force-stage` matched wrong item (last registered)
- Fix: Check if combining prefix token with next token creates full flag match
- Added lookahead in `sync_checkboxes_from_command()` to prioritize full matches
- Files modified: /home/ritz/programming/ai-stuff/scripts/libs/menu.lua

**10-033: Fix HTML Generation Memory Exhaustion** - COMPLETED (2026-03-23)
- Bug: HTML generation with 4 threads caused system OOM (14+ GB RAM usage)
- Root cause 1: Main thread loaded similarity_matrix.json (662MB) + embeddings.json (77MB) that were never used
- Root cause 2: Each effil worker thread independently loaded 700MB+ of cache data
- Fix 1: Skip loading unused files in main.lua - generator uses pre-computed caches
- Fix 2: Changed default thread count from 4 to 1 (single-threaded mode)
- Expected memory usage after fix: ~2-3GB (down from 14+ GB)
- Files modified: src/main.lua, run.sh

**10-034: Lazy Loading Orchestrator for Parallel HTML** - COMPLETED (2026-03-23)
- Implemented orchestrator pattern: main thread serves 80KB work slices
- Workers no longer load 700MB caches (saves ~2.8GB with 4 threads)
- Added message types: REQUEST_WORK, WORK_SLICE, WORK_DONE, SHUTDOWN
- Test result: 15 threads, 8275 poems in 102s (81.1 poems/sec)
- Memory usage stayed under 3GB (vs 14GB+ before)
- Files modified: src/flat-html-generator.lua, run.sh

**10-035: Parallelize Word Page Generation** - OPEN
- Word pages currently generated sequentially (7135 words)
- Each word requires similarity against all 8275 poems (~59M calculations)
- Two options: on-the-fly parallel (workers load embeddings) or pre-compute cache
- Related fix: poem colors path corrected in generate-word-pages.lua

**10-036: Fix Word Page Chronological Links** - COMPLETED (2026-03-23)
- Bug: Per-poem chrono links pointed to `index.html` (a redirect that loses anchors)
- Root cause: `chrono_page_map` used "index" for page 1, and wasn't passed to formatting function
- Fix: Changed to "01" format, passed `chrono_page_map` through call chain
- Files modified: src/generate-word-pages.lua
- Note: Similar bug exists in flat-html-generator.lua:2171 (separate issue)

**10-037: Blank fediverse_boost Content** - OPEN
- Some fediverse_boost entries render with empty content areas
- Example: fediverse_boost/6358 shows blank space between header and navigation
- May indicate extraction issue with certain boost types
- Related to Issue 6-027b (Boost extraction)

**10-038: Separate ID Numbering for fediverse_boost** - OPEN
- fediverse_boost currently shares ID iterator with fediverse category
- Results in interleaved IDs (fediverse/6355, fediverse_boost/6356, fediverse/6359)
- Should have independent numbering like other categories (notes, messages)
- Breaking change requiring cache regeneration

**10-039: Render External Boost URLs as Links** - OPEN
- External boost entries display URLs as plain text
- "External post: https://..." should be clickable
- Allows users to view original boosted content on fediverse

**10-040: Boost Styling Inconsistency Across Page Types** - OPEN
- Boosts use different styling on chronological vs similar/different pages
- Chronological: basic formatting (same as regular posts)
- Similar/different: fancy [BOOST] box with colored frames
- Should use [BOOST] styling consistently across all page types

**10-041: Malformed Boost Box Alignment** - OPEN
- [BOOST] box formatting has misaligned box-drawing characters
- Right-side frame characters don't form straight vertical line
- Width calculations inconsistent between sections
- Foundational fix needed before 10-040 (style propagation)

**10-042: Integrate Standalone Images Into Site** - OPEN
- Image-manager catalogs images but they're never displayed
- Standalone sources: my-art, things-I-almost-posted, poem-pictures, dnd-pictures, fediverse-stars
- Three integration points:
  1. Gallery pages (one per source) linked from chronological header
  2. Chronological interleaving by file timestamp
  3. Similar/different integration via filename embedding
- Future: Vision model or OCR-based embeddings for richer semantics
- Depends on: 6-017 (image catalog), 10-030 (randomize_order)

## Completion Criteria

- [x] Configuration consolidated into single source (10-003, 10-003a, 10-003b)
- [x] CLI flags for all functionality (10-005)
- [x] Pipeline data validation utility (10-011)
- [x] Validation script counts accurate (10-012)
- [x] Unified input sources config (10-015, 10-015a)
- [x] Multi-Ollama server configuration (10-017)
- [x] TUI per-stage regeneration options (10-016)
- [ ] TUI integration for all interactive scripts
- [ ] Test suite integration (10-010)

---

**Phase Status: IN PROGRESS**

**Started**: 2025-12-23

## Related Documents

- `config.lua` - Unified configuration file
- `scripts/validate-pipeline-data` - Validation utility
- `scripts/lua-menu.sh` - TUI library
