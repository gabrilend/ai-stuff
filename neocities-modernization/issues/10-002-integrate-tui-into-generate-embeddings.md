# Issue 10-002: Integrate TUI into generate-embeddings.sh

**Phase:** 10 - Developer Experience & Tooling
**Type:** Enhancement
**Priority:** Medium
**Affects:** generate-embeddings.sh

---

## Current Behavior

The `generate-embeddings.sh` script manages embedding generation for the poetry
collection. It has an interactive mode (`-I`) that uses sequential numbered prompts:

```
=== Embedding Generation Interactive Mode ===

Select processing mode:
1. Incremental (default) - Process only new/changed poems
2. Full regeneration - Regenerate all embeddings
3. Cache management - Flush/validate cache
4. Status check - Show current progress

Choose option (1-4): _
```

Followed by additional prompts for:
- Cache management sub-options (flush all, flush errors, validate)
- Model selection (embeddinggemma, text-embedding-ada-002, etc.)

### Current Flags

```
Processing:
  --incremental, --inc     Use incremental processing (default)
  --full-regen, --full     Force full regeneration

Cache Management:
  --flush-all              Remove all cached embeddings
  --flush-errors           Remove only error entries
  --backup-before-flush    Create backup before flushing (default)
  --no-backup              Skip backup creation
  --validate               Validate cache integrity
  --status                 Show cache status

Model Selection:
  --model=MODEL_NAME       Specify embedding model
  --list-models            Show available models
  --model-status           Show cache status per model
```

### Limitations

1. Sequential prompts require multiple interactions
2. No way to see all options at once
3. No vim-style navigation
4. Can't easily change mind after selecting an option
5. No visual feedback on current selections

---

## Intended Behavior

Replace the sequential prompts with a TUI menu showing all options simultaneously:

### Proposed Menu Structure

```
╔══════════════════════════════════════════════════════════════╗
║              Embedding Generation Manager                     ║
║                    neocities-modernization                    ║
╠══════════════════════════════════════════════════════════════╣
   Processing Mode (select one)
   ─────────────────────────────
1 >[*] Incremental - Process only new/changed poems
2  [ ] Full Regeneration - Regenerate all embeddings
3  [ ] Status Check - Show current progress without processing

   Cache Management
   ────────────────
4  [ ] Flush All Embeddings - Complete cache reset
5  [ ] Flush Errors Only - Remove failed entries, keep valid
6  [ ] Validate Cache - Check integrity without changes

   Cache Options
   ─────────────
7  [*] Backup Before Flush - Create timestamped backup
8  [ ] Skip Confirmation - Don't prompt for dangerous operations

   Model Selection
   ───────────────
9     Model <[EMBEDDINGGEMMA]>
0  [ ] Show Model Status - Display cache stats per model

   Actions
   ───────
      Run -->

───────────────────────────────────────────────────────────────
j/k:nav  space:toggle  `:action  q:quit
╚══════════════════════════════════════════════════════════════╝
```

---

## Suggested Implementation Steps

### Step 1: Add TUI Library Sourcing

```bash
# TUI Library
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
if [ "$INTERACTIVE_MODE" = true ]; then
    source "${LIBS_DIR}/lua-menu.sh"
fi
```

### Step 2: Create Menu Configuration

```bash
setup_embedding_menu() {
    menu_init
    menu_set_title "Embedding Generation Manager" "neocities-modernization"

    # Section 1: Processing Mode (radio buttons - only one can be selected)
    menu_add_section "mode" "single" "Processing Mode"
    menu_add_item "mode" "incremental" "Incremental" "checkbox" "1" \
        "Process only new or changed poems (fastest)"
    menu_add_item "mode" "full_regen" "Full Regeneration" "checkbox" "0" \
        "Regenerate all embeddings from scratch"
    menu_add_item "mode" "status_only" "Status Check" "checkbox" "0" \
        "Show current progress without processing"

    # Section 2: Cache Management (can select multiple, but some are exclusive)
    menu_add_section "cache" "multi" "Cache Management"
    menu_add_item "cache" "flush_all" "Flush All Embeddings" "checkbox" "0" \
        "WARNING: Removes entire cache, requires full regeneration"
    menu_add_item "cache" "flush_errors" "Flush Errors Only" "checkbox" "0" \
        "Remove failed embedding attempts, keep successful ones"
    menu_add_item "cache" "validate" "Validate Cache" "checkbox" "0" \
        "Check cache integrity and report issues"

    # Section 3: Cache Options
    menu_add_section "cache_opts" "multi" "Cache Options"
    menu_add_item "cache_opts" "backup" "Backup Before Flush" "checkbox" "1" \
        "Create timestamped backup before any flush operation"
    menu_add_item "cache_opts" "force" "Skip Confirmation" "checkbox" "0" \
        "Don't prompt for confirmation on destructive operations"

    # Section 4: Model Selection
    menu_add_section "model" "multi" "Model Selection"
    menu_add_item "model" "model_name" "Model" "multistate" "embeddinggemma" \
        "embeddinggemma,text-embedding-ada-002,nomic-embed-text"
    menu_add_item "model" "model_status" "Show Model Status" "checkbox" "0" \
        "Display cache statistics for each model"

    # Section 5: Actions
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run" "action" "" \
        "Execute with selected options"
}
```

### Step 3: Map Menu Results to Flags

```bash
apply_menu_selections() {
    # Processing mode (radio - only one should be set)
    if [[ "$(menu_get_value "incremental")" == "1" ]]; then
        INCREMENTAL=true
        FORCE_REGEN=false
    elif [[ "$(menu_get_value "full_regen")" == "1" ]]; then
        INCREMENTAL=false
        FORCE_REGEN=true
    elif [[ "$(menu_get_value "status_only")" == "1" ]]; then
        SHOW_STATUS=true
    fi

    # Cache management
    [[ "$(menu_get_value "flush_all")" == "1" ]] && FLUSH_ALL=true
    [[ "$(menu_get_value "flush_errors")" == "1" ]] && FLUSH_ERRORS=true
    [[ "$(menu_get_value "validate")" == "1" ]] && VALIDATE_CACHE=true

    # Cache options
    [[ "$(menu_get_value "backup")" == "1" ]] && BACKUP_BEFORE_FLUSH=true || BACKUP_BEFORE_FLUSH=false
    [[ "$(menu_get_value "force")" == "1" ]] && FORCE_OPERATION=true

    # Model selection
    local model=$(menu_get_value "model_name")
    case "$model" in
        "embeddinggemma") MODEL_NAME="embeddinggemma:latest" ;;
        "text-embedding-ada-002") MODEL_NAME="text-embedding-ada-002" ;;
        "nomic-embed-text") MODEL_NAME="nomic-embed-text" ;;
    esac

    [[ "$(menu_get_value "model_status")" == "1" ]] && MODEL_STATUS=true
}
```

### Step 4: Replace Interactive Mode Section

Replace lines 109-170 (current interactive mode) with:

```bash
# Interactive mode handling
if [ "$INTERACTIVE_MODE" = true ]; then
    setup_embedding_menu

    if menu_run; then
        apply_menu_selections
        # Continue with normal execution using the set flags
    else
        echo "Operation cancelled."
        exit 0
    fi
fi
```

### Step 5: Add Validation Logic

Some options are mutually exclusive or have dependencies:

```bash
validate_selections() {
    # Can't flush and just show status
    if [[ "$FLUSH_ALL" == "true" || "$FLUSH_ERRORS" == "true" ]] && [[ "$SHOW_STATUS" == "true" ]]; then
        echo "Warning: Flush operations override status-only mode"
        SHOW_STATUS=false
    fi

    # flush_all and flush_errors are mutually exclusive
    if [[ "$FLUSH_ALL" == "true" ]] && [[ "$FLUSH_ERRORS" == "true" ]]; then
        echo "Warning: flush-all takes precedence over flush-errors"
        FLUSH_ERRORS=false
    fi
}
```

---

## Acceptance Criteria

- [ ] TUI menu displays all option categories
- [ ] Processing mode section acts as radio buttons (single selection)
- [ ] Cache management options can be multi-selected where appropriate
- [ ] Model selection cycles through available models
- [ ] Backup option defaults to checked
- [ ] Menu values correctly map to existing flag variables
- [ ] Existing flag-based operation unchanged
- [ ] Dangerous operations (flush) show appropriate warnings
- [ ] q/ESC cancels without executing
- [ ] Run action executes with selected configuration

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/README-lua-menu-dev.md` - Integration guide
- Issue 10-001 - phase-demo.sh integration (similar approach)
- `libs/ollama-config.lua` - Model configuration reference

---

## Notes

The script currently has ~25KB of code. The TUI integration primarily affects
the interactive mode section (lines 109-170). The rest of the script's logic
for actually generating embeddings, managing cache, etc. remains unchanged.

Consider adding a "dry run" checkbox that shows what would be done without
actually executing, especially useful for flush operations.
