# 10-032: Fix Shared Flag Prefix Collision in TUI Command Sync

## Current Behavior

When moving the cursor from the command preview to another menu item (e.g., "Run Selected Stages"), checkboxes with space-separated flag values (like `--force-stage 9`) get incorrectly deselected.

**Reproduction steps:**
1. Open `./run.sh -I` (interactive TUI mode)
2. Enable "9. Generate HTML" stage
3. Enable "Force regenerate" checkbox for stage 9 (adds `--force-stage 9` to command)
4. Navigate cursor to the command preview
5. Navigate cursor away from command preview to "Run Selected Stages"
6. Observe: Stage 9's force regenerate checkbox is now deselected

## Root Cause

The `build_flag_lookup()` function in `menu.lua` stores both full flags and their prefixes:
- `lookup["--force-stage 9"]` = `force_generate_html`
- `lookup["--force-stage"]` = `force_generate_html`

However, ALL `--force-stage N` items share the same prefix `--force-stage`. Since items are processed in order, the prefix key gets overwritten by each subsequent item. The last item (`--force-stage 10` → `force_generate_index`) "wins" the prefix.

When `sync_checkboxes_from_command()` parses the command text `./run.sh --force-stage 9`:
1. The command is tokenized as separate tokens: `--force-stage`, `9`
2. Token `--force-stage` is looked up → finds `force_generate_index` (wrong item!)
3. `found_flags["force_generate_index"]` = true
4. Token `9` is treated as unrecognized (not consumed as part of the flag)
5. `force_generate_html` is never found, so it gets unchecked (line 1413)

## Intended Behavior

When parsing a command that contains `--force-stage 9`, the correct checkbox (`force_generate_html`) should be marked as found, preserving its checked state.

## Suggested Implementation Steps

1. In `sync_checkboxes_from_command()`, after finding a prefix match, check if combining with the next token creates a full flag match
2. If a full flag match exists and has a different item_id, use that instead
3. Skip the value token since it's now part of the flag

## Implementation (Completed)

Added check in `sync_checkboxes_from_command()` (lines 1308-1321):

```lua
-- Issue 10-008b: Check if combining with next token creates a full flag match
-- This handles flags like "--force-stage 9" where the prefix "--force-stage"
-- might match the wrong item due to multiple items sharing the same prefix.
-- We prioritize the full match (e.g., "--force-stage 9") over prefix match.
if flag_info and i < #tokens then
    local next_token = tokens[i + 1]
    local combined_flag = token.text .. " " .. next_token.text
    local full_flag_info = flag_lookup[combined_flag]
    if full_flag_info then
        -- Full flag match found - use it instead of prefix match
        flag_info = full_flag_info
        i = i + 1  -- Skip the value token since it's part of the flag
    end
end
```

## Related Documents

- `menu.lua` - TUI library with bidirectional command sync
- `run.sh` - Uses TUI for interactive pipeline configuration
- Issue 10-016 - Introduced per-stage force regeneration options

## Status

**IMPLEMENTED** - Fix applied to `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`

## Notes

- This fix affects all checkbox-type items with space-separated flag values
- Coloring of the value token (e.g., `9`) is not addressed - this is a cosmetic issue
- The prefix lookup is still useful for flag-type items (which consume the next token as their value)
