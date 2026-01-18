# Issue 10-011: Implement Pipeline Data Validation Utility

## Status
- **Phase**: 10 (Developer Experience)
- **Priority**: Medium
- **Type**: Tooling / Validation
- **Status**: Open
- **Created**: 2026-01-17

## Current Behavior

Developers must manually check multiple locations to assess pipeline readiness:

```bash
# Check embeddings
find input/embeddings -name "*.json" | wc -l
wc -l assets/poems.json

# Check similarity matrix
ls temp/similarity_matrix/*.json | wc -l

# Check diversity cache
test -f temp/diversity_cache.json && echo "exists" || echo "missing"

# No way to validate if data is stale
# No way to detect which poems are missing from matrix/cache
# No unified status display
```

**Problems:**
1. No single command to check pipeline readiness
2. No validation that cached data matches current poem corpus
3. No detection of newly added poems since last generation
4. No way to identify specific missing entries
5. No ETA calculation for incomplete datasets

## Intended Behavior

Create `scripts/validate-pipeline-data` utility that provides comprehensive pipeline status validation, with **mandatory integration** into `run.sh` and all pipeline scripts.

The utility must serve dual purposes:
1. **Standalone tool**: Manual pipeline status checks
2. **Integrated validation**: Automatic dependency checking in pipeline scripts

### Core Features

### 1. Completion Status Display

```
Pipeline Data Validation Report
═══════════════════════════════════════════════════════════════

Poem Corpus
  ├─ Total poems: 7,793
  ├─ Source file: assets/poems.json
  └─ Last modified: 2026-01-15 14:23:01

Embeddings
  ├─ Progress: 7,793 / 7,793 (100.0%) ✓
  ├─ Location: input/embeddings/embeddinggemma_latest/
  ├─ Model: embeddinggemma:latest
  ├─ Last generated: 2026-01-15 16:45:22
  └─ Status: UP-TO-DATE ✓

Similarity Matrix
  ├─ Progress: 1,671 / 7,793 (21.4%) ⚠
  ├─ Location: temp/similarity_matrix/
  ├─ Missing entries: 6,122
  ├─ Last generated: 2026-01-04 09:12:45
  ├─ Estimated time to complete: ~2.1 hours (8 threads)
  └─ Status: INCOMPLETE (run: lua src/similarity-engine-parallel.lua)

Diversity Cache
  ├─ Progress: 0 / 7,793 (0.0%) ✗
  ├─ Location: temp/diversity_cache.json
  ├─ Cache size: N/A (not generated)
  ├─ Estimated time to complete: ~42 hours (8 threads)
  └─ Status: MISSING (run: ./scripts/precompute-diversity-sequences)

HTML Output
  ├─ Similar pages: 6 / 116,895 (0.005%)
  ├─ Different pages: 4 / 116,895 (0.003%)
  ├─ Chronological: 1 / 1 (100%) ✓
  └─ Status: INCOMPLETE (blocked by similarity matrix)

═══════════════════════════════════════════════════════════════
Overall Status: NOT READY FOR DEPLOYMENT
Next Step: Complete similarity matrix generation
Command: lua src/similarity-engine-parallel.lua
```

### 2. Freshness Validation

Detects when cached data is stale:

```bash
./scripts/validate-pipeline-data --check-freshness

Freshness Analysis
═══════════════════════════════════════════════════════════════

Embeddings: STALE ⚠
  ├─ embeddings.json: 2026-01-04 12:00:00
  ├─ poems.json: 2026-01-15 14:23:01
  ├─ Age difference: 11 days old
  └─ Action: Re-run ./generate-embeddings.sh --incremental

Similarity Matrix: STALE ⚠
  ├─ Latest file: 2026-01-04 09:12:45
  ├─ embeddings.json: 2026-01-15 16:45:22
  ├─ Age difference: 11 days old
  └─ Action: Re-run lua src/similarity-engine-parallel.lua

Diversity Cache: N/A
  └─ File does not exist

═══════════════════════════════════════════════════════════════
Recommendation: Regenerate embeddings and similarity matrix
```

### 3. Missing Entry Detection

Identifies specific poems missing from matrix/cache:

```bash
./scripts/validate-pipeline-data --list-missing

Missing Similarity Matrix Entries
═══════════════════════════════════════════════════════════════
  72 poems missing from similarity matrix:

  0001, 0034, 0067, 0089, 0123, 0156, 0189, 0234, 0267,
  0301, 0334, 0367, 0401, 0434, 0467, 0501, 0534, 0567,
  ... (52 more)

Missing Diversity Cache Entries
═══════════════════════════════════════════════════════════════
  All 7,793 poems missing (cache not generated)

═══════════════════════════════════════════════════════════════
```

### 4. Incremental Validation Mode

Fast check for CI/CD integration:

```bash
./scripts/validate-pipeline-data --quick

STATUS: NOT_READY
EMBEDDINGS: 100% (7793/7793) UP_TO_DATE
SIMILARITY: 21% (1671/7793) INCOMPLETE
DIVERSITY: 0% (0/7793) MISSING
HTML_SIMILAR: 0% (6/116895) INCOMPLETE
HTML_DIFFERENT: 0% (4/116895) INCOMPLETE

EXIT_CODE: 1 (not ready for deployment)
```

## Suggested Implementation Steps

### Phase A: Core Status Checking

1. Create `scripts/validate-pipeline-data` bash script
2. Implement poem corpus counting from `assets/poems.json`
3. Implement embedding counting from `input/embeddings/*/`
4. Implement similarity matrix file counting from `temp/similarity_matrix/`
5. Implement diversity cache validation (file exists + JSON parsing)
6. Implement HTML output counting from `output/similar/` and `output/different/`

### Phase B: Freshness Validation

7. Add mtime (modification time) checking for key files
8. Implement dependency chain validation:
   - poems.json → embeddings.json
   - embeddings.json → similarity_matrix/*
   - embeddings.json → diversity_cache.json
   - similarity_matrix + diversity_cache → HTML output
9. Add `--check-freshness` flag
10. Implement age difference calculation and reporting

### Phase C: Missing Entry Detection

11. Parse `assets/poems.json` to get all poem IDs
12. Parse `input/embeddings/embeddinggemma_latest/embeddings.json` to get embedded IDs
13. Check `temp/similarity_matrix/` for missing NNNN.json files
14. Add `--list-missing` flag with formatted output
15. Optional: Save missing list to temp file for pipeline consumption

### Phase D: Progress Estimation

16. Add time estimation based on:
    - Similarity matrix: ~0.92 seconds per poem (8 threads)
    - Diversity cache: ~19.4 seconds per poem (8 threads)
17. Calculate ETAs for incomplete datasets
18. Add configurable thread count via `--threads=N` flag

### Phase E: Integration & Output Modes

19. Add `--quick` flag for machine-readable output
20. Add `--format=json` for structured data export
21. Add exit codes: 0 = ready, 1 = incomplete, 2 = stale
22. Create `libs/pipeline-validator.lua` module for use in other scripts
23. Integrate into TUI menu as "Check Pipeline Status" option

### Phase F: Auto-Fix Suggestions

24. Add `--suggest-commands` flag that outputs exact commands to fix issues:
    ```
    To complete pipeline, run these commands:

    # Step 1: Generate missing embeddings (ETA: 15 minutes)
    ./generate-embeddings.sh --incremental

    # Step 2: Complete similarity matrix (ETA: 2.1 hours)
    lua src/similarity-engine-parallel.lua

    # Step 3: Pre-compute diversity cache (ETA: 42 hours, can run overnight)
    nohup ./scripts/precompute-diversity-sequences > temp/diversity.log 2>&1 &

    # Step 4: Generate all HTML pages (ETA: 1 hour)
    ./scripts/generate-html-parallel 8 --pages=all
    ```

### Phase G: Pipeline Integration

25. Integrate into `run.sh` as automatic validation step:
    - Run validation before HTML generation stage
    - Display status summary after each major pipeline stage
    - Add `--skip-validation` flag to bypass checks for speed
    - Fail early with clear error if dependencies missing

26. Create `libs/pipeline-validator.lua` module for Lua script integration:
    - Export validation functions for use in other scripts
    - Functions: `check_similarity_matrix()`, `check_diversity_cache()`, `check_embeddings()`
    - Return structured data: `{complete = bool, count = num, total = num, missing = []}`

27. Update `scripts/generate-html-parallel` to validate before generation:
    - Check similarity matrix completeness before similar page generation
    - Check diversity cache before different page generation
    - Display helpful error with exact command to fix if incomplete
    - Optional `--force` flag to generate with incomplete data (partial output)

28. Update `scripts/precompute-diversity-sequences` to validate before starting:
    - Check similarity matrix exists and is complete
    - Check embeddings are up-to-date
    - Display warning if starting with stale/incomplete data

29. Update `src/similarity-engine-parallel.lua` to validate before starting:
    - Check embeddings.json exists and matches poem count
    - Display summary of what will be generated
    - Optional resume capability if partial matrix exists

30. Add validation to TUI menu in `run.sh`:
    - Show real-time status in stage selection screen
    - Display completion percentages next to each stage
    - Color-code stages: green (complete), yellow (incomplete), red (missing)
    - Example: `[6] Generate Embeddings ✓ 100% (7793/7793)`

## Quality Assurance Criteria

### Core Validation
- [ ] Correctly counts all poems from poems.json
- [ ] Accurately reports embedding completion percentage
- [ ] Detects missing similarity matrix files
- [ ] Validates diversity cache JSON structure
- [ ] Identifies stale data based on file timestamps
- [ ] Reports missing entries by poem ID
- [ ] Provides accurate time estimates
- [ ] Exit codes work correctly for CI/CD integration
- [ ] `--quick` mode completes in <1 second
- [ ] JSON output is valid and parseable
- [ ] Works with partially completed datasets
- [ ] Handles missing directories gracefully
- [ ] All file paths configurable via environment variables

### Integration Requirements
- [ ] Integrated into `run.sh` pipeline as automatic validation
- [ ] `libs/pipeline-validator.lua` module works from Lua scripts
- [ ] `scripts/generate-html-parallel` validates dependencies before generation
- [ ] `scripts/precompute-diversity-sequences` validates before starting
- [ ] `src/similarity-engine-parallel.lua` validates before starting
- [ ] TUI menu shows real-time completion percentages
- [ ] `--skip-validation` flag works to bypass checks
- [ ] Validation errors include exact fix commands
- [ ] Color-coded status in TUI (green/yellow/red)
- [ ] All integrated scripts fail early with helpful errors

## Configuration

Add to `config/input-sources.json`:

```json
"validation": {
    "embeddings_path": "input/embeddings/embeddinggemma_latest/embeddings.json",
    "similarity_matrix_dir": "temp/similarity_matrix",
    "diversity_cache_file": "temp/diversity_cache.json",
    "output_similar_dir": "output/similar",
    "output_different_dir": "output/different",
    "warn_age_threshold_days": 7,
    "error_age_threshold_days": 30
}
```

## Dependencies

- `jq` for JSON parsing (already used in project)
- `find`, `wc`, `stat` for file operations (standard Unix tools)
- `assets/poems.json` (poem corpus)
- Access to all pipeline data directories

## Performance Considerations

- File counting should use `find | wc -l` (fast)
- JSON parsing should use `jq` length (fast)
- Avoid reading large files completely (use head/tail for timestamps)
- Cache poem count for repeated checks (don't re-parse poems.json)
- `--quick` mode should complete in <1 second for responsive CI/CD

## Use Cases

### 1. Pre-Deployment Check
```bash
./scripts/validate-pipeline-data
# Review status before running deployment
```

### 2. CI/CD Integration
```bash
if ! ./scripts/validate-pipeline-data --quick; then
    echo "Pipeline not ready, skipping deployment"
    exit 1
fi
```

### 3. Incremental Updates
```bash
# Check what needs updating after adding new poems
./scripts/validate-pipeline-data --check-freshness --list-missing
```

### 4. Automated Fix
```bash
# Get commands to run for completion
./scripts/validate-pipeline-data --suggest-commands > /tmp/pipeline-fix.sh
bash /tmp/pipeline-fix.sh
```

### 5. Integration with run.sh
```bash
# Automatic validation in run.sh before HTML generation
./run.sh --all  # Runs validation automatically before stage 9

# TUI menu integration
[8] Check pipeline status
[9] Validate and suggest fixes

# Example run.sh validation output:
Stage 6: Generate Embeddings ✓ 100% (7793/7793)
Stage 7: Build Similarity Matrix ⚠ 21% (1671/7793) - INCOMPLETE
Stage 8: Build Diversity Cache ✗ 0% (0/7793) - MISSING
Stage 9: Generate HTML - BLOCKED (dependencies incomplete)

Run with --skip-validation to bypass checks
```

### 6. Script Integration - generate-html-parallel
```bash
# Script validates before generation
./scripts/generate-html-parallel 8 --pages=all

# Output if incomplete:
✗ ERROR: Similarity matrix incomplete (1671/7793 files)
Cannot generate similar pages without complete similarity matrix.

To fix, run:
  lua src/similarity-engine-parallel.lua

Or use --force to generate with partial data (not recommended)
```

### 7. Script Integration - precompute-diversity-sequences
```bash
# Script validates before starting
./scripts/precompute-diversity-sequences

# Output if stale:
⚠ WARNING: Embeddings are stale
  embeddings.json: 2026-01-04
  poems.json: 2026-01-15

Diversity cache will use outdated embeddings.
Recommend running: ./generate-embeddings.sh --incremental

Continue anyway? [y/N]
```

### 8. Script Integration - similarity-engine-parallel.lua
```bash
# Script validates before starting
lua src/similarity-engine-parallel.lua

# Output:
Similarity Matrix Generation
═══════════════════════════════════════════════════════════════
Embeddings: ✓ 7,793 poems embedded
Existing matrix: 1,671 files (21.4% complete)
Will generate: 6,122 new files

Estimated time: ~2.1 hours (8 threads)
Resume capability: ✓ (skips existing files)

Press Ctrl+C to cancel...
Starting in 3... 2... 1...
```

## Related Issues

- **8-001**: Unified website generation pipeline
- **8-002**: Multi-threaded HTML generation
- **10-010**: Integrate test suites into development pipeline
- **CRITICAL-PATH-SIMILAR.md**: Similar pages critical path
- **CRITICAL-PATH-DIFFERENT.md**: Different pages critical path

## Related Documents

### Documentation
- `/docs/roadmap.md` - Pipeline stages documentation
- `/issues/CRITICAL-PATH-SIMILAR.md` - Similar generation requirements
- `/issues/CRITICAL-PATH-DIFFERENT.md` - Different generation requirements

### Scripts to Integrate Validation
- **`run.sh`** - Main pipeline orchestrator (MUST integrate validation)
- **`scripts/generate-html-parallel`** - HTML generation script (MUST validate before running)
- **`scripts/precompute-diversity-sequences`** - Diversity cache generator (MUST validate before running)
- **`src/similarity-engine-parallel.lua`** - Similarity matrix generator (MUST validate before running)
- **`generate-embeddings.sh`** - Embedding generator (SHOULD validate poem count)
- **`src/main.lua`** - TUI menu (SHOULD show validation status)

### Modules to Create
- **`libs/pipeline-validator.lua`** - Lua module for validation functions (NEW)
- **`scripts/validate-pipeline-data`** - Standalone validation script (NEW)

## Notes

### Integration Strategy

**Why Integration Matters:**

The validation utility must be integrated into the pipeline, not just available as a standalone tool. This prevents common failure modes:

1. **Fail-Fast Philosophy**: Per CLAUDE.md guidelines, prefer breaking with clear errors over silent failures
   - Scripts should validate dependencies before starting long computations
   - Better to fail in 1 second with helpful error than waste 2 hours generating corrupt data

2. **User Experience**: Running a 2-hour similarity matrix calculation only to discover embeddings were stale
   - Validation takes <1 second, provides immediate feedback
   - Saves hours of wasted computation time

3. **Pipeline Reliability**: `run.sh` orchestrates 10 stages with complex dependencies
   - Validation ensures stages run in correct order
   - Prevents partial/corrupt output from incomplete inputs

4. **Development Velocity**: TUI showing real-time status reduces cognitive load
   - No need to manually check 5+ locations to assess readiness
   - Immediate visual feedback on what's blocking deployment

**Integration Priority:**

| Script | Priority | Reason |
|--------|----------|--------|
| `run.sh` | **CRITICAL** | Orchestrates entire pipeline, must validate dependencies |
| `generate-html-parallel` | **CRITICAL** | Final output stage, must ensure inputs complete |
| `precompute-diversity-sequences` | **HIGH** | Long-running (42 hrs), must validate before starting |
| `similarity-engine-parallel.lua` | **HIGH** | Long-running (2 hrs), must validate before starting |
| `main.lua` TUI | **MEDIUM** | Improves UX but not blocking |
| `generate-embeddings.sh` | **LOW** | Has basic validation, enhancement only |

### Directory Stability

The validation utility should support multiple embedding models via directory structure:
```
input/embeddings/
├── embeddinggemma_latest/
│   ├── embeddings.json
│   └── similarity_matrix.json
├── model_name_2/
│   └── embeddings.json
└── [additional models...]
```

The `--model` flag should allow validating specific embedding models.

### Diversity Cache Structure

The diversity cache is a single JSON file but contains 7,793 pre-computed sequences:
```json
{
    "1": [sorted_poem_ids...],
    "2": [sorted_poem_ids...],
    ...
    "7793": [sorted_poem_ids...]
}
```

Validation should:
1. Check file exists
2. Parse as valid JSON
3. Count number of sequences
4. Optionally validate sequence completeness (all poems present in each sequence)

### Performance Targets

| Operation | Target Time | Notes |
|-----------|-------------|-------|
| Full validation | <5 seconds | All checks including freshness |
| Quick mode | <1 second | Status only, no missing entry detection |
| Missing entry list | <3 seconds | Parse and diff operations |
| JSON export | <2 seconds | Structured output generation |

### Exit Codes

| Code | Meaning | Use Case |
|------|---------|----------|
| 0 | Ready for deployment | All data complete and fresh |
| 1 | Incomplete | Missing data, can be fixed |
| 2 | Stale | Data exists but outdated |
| 3 | Configuration error | Missing required files/directories |

---

**ISSUE STATUS: OPEN**

**Created**: 2026-01-17

**Phase**: 10 (Developer Experience)

**Priority**: Medium (nice-to-have for MVP, essential for production)
