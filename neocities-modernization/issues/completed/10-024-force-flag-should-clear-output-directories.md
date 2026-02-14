# Issue 10-024: Force Flag Should Clear Output Directories

## Status: COMPLETED

## Current Behavior

When using `--force` or `--force-stage=9` for HTML generation:

1. The freshness check is bypassed (regeneration proceeds)
2. Files are overwritten one-by-one
3. **Stale files with obsolete poem_index values remain in the output directory**

This caused a bug where clicking "similar" links showed the wrong poem:
- `similar/7721-01.html` was generated Jan 31 when poem_index 7721 was "music is an example..."
- After re-extraction on Feb 13, poem_index 7721 became "I am a slow burn..."
- The stale HTML file still showed the old content

## Intended Behavior

When `--force` is used for a stage, the stage should clear its output directories before regenerating:

- Stage 9 (HTML generation): Clear `output/similar/`, `output/different/`, `output/chronological/`
- Other stages should follow the same pattern for their output directories

This ensures a clean state with no orphaned or stale files.

## Implementation

### run.sh (run_generate_html function)

Add directory clearing when force flag is set:

```bash
run_generate_html() {
    log_stage "🌐 Stage 9/10: Generating website HTML"

    # Issue 10-016: Check both global and per-stage force flags (Stage 9)
    local stage_force=$FORCE
    $FORCE_STAGE_9 && stage_force=true

    # Issue 10-024: Clear output directories when forcing regeneration
    if $stage_force; then
        log_info "   Clearing stale HTML files (--force)..."
        rm -f "$DIR/output/similar/"*.html 2>/dev/null
        rm -f "$DIR/output/different/"*.html 2>/dev/null
        # Note: chronological/ has fewer files and is always overwritten, but clear for consistency
        rm -f "$DIR/output/chronological/"*.html 2>/dev/null
    fi

    # ... rest of function
}
```

### Design Considerations

1. **Only clear HTML files, not directories** - Preserves directory structure and any non-HTML files
2. **Clear at run.sh level, not Lua level** - Pipeline orchestration belongs in the shell script
3. **Log the clearing action** - User visibility into what's happening
4. **Apply to all HTML output directories** - similar/, different/, chronological/

## Files to Modify

- `run.sh` - Add directory clearing in `run_generate_html()`

## Related Issues

- 10-016: Per-stage force flags
- 10-022: Fix empty embeddings validation (similar "stale data" pattern)

## Lessons Learned

1. Force regeneration should mean "start fresh", not just "ignore freshness checks"
2. When data identifiers (like poem_index) can change between runs, old output files become orphaned
3. Pipeline stages should clean their output directories when forcing full regeneration

## Completed

2026-02-13
