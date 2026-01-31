# Issue 7-003: Cleanup run.sh Output Formatting

## Priority
Medium

## Current Behavior

The `run.sh` output has several formatting issues that reduce clarity and violate the principle that **each line should mean one thing, and that thing should never be duplicated**.

### Problem 1: Duplicate Progress Messages

```
📦 Extracting ZIP archives...
🔄 Starting ZIP archive extraction...
```

Two lines saying the same thing. Keep the one with the cute box emoji.

### Problem 2: Redundant Completion Messages

```
✅ Extracted media_attachments directory
✅ Successfully extracted fediverse data from most-recent-29
```

Either enumerate ALL extracted items (verbose mode) OR just show the final summary (normal mode), not both partial and complete.

### Problem 3: Repeated Task Completion

```
📋 Extraction summary:
   Archives processed: 2/2
   ...
✅ ZIP archive extraction completed
```

The summary already implies completion. The additional "completed" line is redundant.

### Problem 4: Unclear Byte Counts

```
📦 Read 86122 bytes
```

What bytes? From what file? This line lacks context.

### Problem 5: Relative Paths in Output

```
Project directory: ./
Temporary directory: ./temp/extract-1769807114
```

Design constraint: Use absolute paths everywhere. The `relative_path()` function returns "./" which is unclear. Should show full absolute path or a meaningful relative-to-project indicator.

### Problem 6: Force-Regenerate Doesn't Regenerate

With `--force-regenerate` selected:
```
💾 Preserved 3 generated file directories
♻️  Restored 3 generated file directories
```

Force-regenerate should NOT preserve files — it should recreate from scratch. The preserve/restore logic in `scripts/update-words` doesn't check the force flag.

### Problem 7: Inconsistent Color Usage

Output uses emojis but colors should be semantically meaningful:
- **Green**: Milestones only (stage completion, phase transitions)
- **White**: Normal output, success messages, data
- **Cyan**: Info/progress indicators
- **Yellow**: Attention needed (non-fatal but noteworthy)
- **Red**: Fatal errors (execution stops)
- **Magenta**: Section headers

### Problem 8: Warnings That Should Be Errors

**Design Constraint: Configuration problems are fatal.**

Current behavior allows execution to continue after problems:
```
📷 Syncing images from 2 configured source(s)...
   ⚠  fediverse_media: source not found (/home/ritz/backups/words/fediverse/media_attachments)
   ✓ my-art: 158 files synced
📷 Total: 158 new files synced to input/media_attachments
```

This is wrong. If a configured source doesn't exist, the pipeline should **fail immediately** with an error, not continue with partial data. Silent failures lead to:
- Incomplete output that appears complete
- Debugging nightmares ("why are my fediverse images missing?")
- False confidence in pipeline integrity

**Rule**: Configuration errors must stop execution. Either:
1. Fix the underlying problem (the source path is wrong)
2. Remove the source from config (it's intentionally absent)
3. Add an explicit `optional: true` flag for sources that may legitimately not exist

**Distinction**:
- **Yellow (attention)**: Truly optional/informational situations where the pipeline *can* reasonably continue (e.g., "Skipping 3 empty poems" - they have no content, that's expected)
- **Red (error)**: Configuration is broken, required data is missing, or the output would be incomplete/wrong

The `⚠` with "source not found" pattern should become:
- `✗ fediverse_media: source not found (stopping)` + `exit 1`

## Intended Behavior

### Principle: One Line, One Truth

Every output line should:
1. Convey exactly one piece of information
2. Never be duplicated by another line
3. Be actionable or informative

### Verbose vs Normal Mode

**Normal mode** (default):
```
📦 Extracting archives...
   ✓ messages: 1 archive
   ✓ fediverse: 1 archive (media_attachments included)
```

**Verbose mode** (`-v` flag):
```
📦 Extracting archives...
   → messages/similar-different.zip
     ✓ Extracted to temp/extract-xxx/messages
   → fediverse/most-recent-29.zip
     ✓ Extracted media_attachments directory
     ✓ Extracted outbox.json
📋 Summary: 2/2 archives processed
```

### Semantic Colors

| Color | Meaning | Example |
|-------|---------|---------|
| Green | Milestone | `✓ Stage 3/10 complete` |
| White | Normal/Success/Data | `✓ Extracted 2 archives`, `Total: 7844 poems` |
| Cyan | Progress indicator | `→ Processing poem 100/7844` |
| Yellow | Attention (non-fatal) | `! Skipping empty file` |
| Red | Fatal error | `✗ Source not found (stopping)` |
| Magenta | Section header | `═══ Extracting ═══` |

**Note**: Yellow means "I noticed something you should know about" but execution continues. Red means "I cannot continue" and execution stops.

### Absolute Paths

Replace:
```
Project directory: ./
```

With:
```
Project directory: /mnt/mtwo/programming/ai-stuff/neocities-modernization
```

Or if relative paths are preferred for readability:
```
Project directory: neocities-modernization/
```

### Force-Regenerate Behavior

When `--force-regenerate` is active:
- Skip the preserve/restore logic entirely
- Display: `🔄 Force regenerate: skipping file preservation`
- Regenerate everything from scratch

## Affected Files

| File | Issues |
|------|--------|
| `scripts/update-words` | Force-regenerate flag, preserve logic |
| `scripts/zip-extractor.lua` | Duplicate messages, relative paths |
| `scripts/extract-bluesky.lua` | Unclear byte count message |
| `run.sh` | Color consistency, verbose mode |
| `libs/utils.lua` | `relative_path()` function behavior |

## Suggested Implementation Steps

1. **Audit all print statements** in pipeline scripts
2. **Create output style guide** documenting color/emoji conventions
3. **Implement verbose flag** (`-v`) for detailed output
4. **Add force-regenerate check** to preserve/restore logic
5. **Fix relative_path()** to return absolute or meaningful relative
6. **Remove duplicate lines** throughout pipeline
7. **Add context to data lines** (bytes read from X, etc.)
8. **Convert all warnings to errors** - grep for `⚠` and replace with either:
   - `✗` + `exit 1` (if the condition is a problem)
   - Remove entirely (if the condition is expected/acceptable)
9. **Add `optional: true` flag** to config sources that may legitimately be absent

## Output Style Guide (Proposed)

```lua
-- libs/output.lua
-- Semantic output with consistent color meanings

local output = {}

-- Colors
output.GREEN = "\27[32m"    -- Milestones only
output.WHITE = "\27[37m"    -- Normal output (often just use no color)
output.CYAN = "\27[36m"     -- Progress indicators
output.YELLOW = "\27[33m"   -- Attention (non-fatal)
output.RED = "\27[31m"      -- Fatal errors
output.MAGENTA = "\27[35m"  -- Section headers
output.RESET = "\27[0m"

-- Semantic output functions
function output.milestone(msg) print(output.GREEN .. "✓ " .. msg .. output.RESET) end
function output.success(msg) print("✓ " .. msg) end  -- White (no color code needed)
function output.info(msg) print(output.CYAN .. "→ " .. msg .. output.RESET) end
function output.attention(msg) print(output.YELLOW .. "! " .. msg .. output.RESET) end
function output.header(msg) print(output.MAGENTA .. "═══ " .. msg .. " ═══" .. output.RESET) end
function output.data(msg) print("  " .. msg) end

-- Errors are fatal - print to stderr and exit
function output.error(msg)
    io.stderr:write(output.RED .. "✗ " .. msg .. output.RESET .. "\n")
    os.exit(1)
end

return output
```

## Implementation Notes

### Problem 1 & 3: Duplicate/Redundant Messages - FIXED

Removed from `scripts/zip-extractor.lua`:
- "🔄 Starting ZIP archive extraction..." (duplicate of parent message)
- "✅ ZIP archive extraction completed" (redundant with summary)

### Problem 5: Relative Paths - FIXED

Updated `relative_path()` function in 9 files to show project name instead of "./" when path equals DIR:
- `libs/utils.lua`
- `scripts/zip-extractor.lua`
- `scripts/generate-html-parallel`
- `scripts/precompute-diversity-sequences`
- `scripts/extract-fediverse.lua`
- `scripts/extract-messages.lua`
- `scripts/extract-notes.lua`
- `scripts/test-html-generation`
- `scripts/test-diversity-quick`

**Before**: `Project directory: ./`
**After**: `Project directory: neocities-modernization/`

### Problem 6: Force-Regenerate - FIXED

Updated `scripts/update-words` and `run.sh`:
- Added `--force` flag parsing to `scripts/update-words`
- `run.sh` now passes `$FORCE` flag to update-words
- When `--force` active: skips preserve/restore, shows "🔄 Force regenerate: skipping file preservation"

### Problem 8: Warnings That Should Be Errors - FIXED

Updated `scripts/update-words` and `config.lua`:
- Added `optional: true/false` flag to image sync sources in config
- Missing required sources now cause fatal error with `exit 1`
- Missing optional sources show yellow attention message: `! source_name: skipped (source not found)`

### Files Modified

| File | Changes |
|------|---------|
| `config.lua` | Added `optional` field to image_sync sources |
| `scripts/update-words` | Added `--force` flag, `optional` source handling |
| `run.sh` | Pass `$FORCE` flag to update-words |
| `scripts/zip-extractor.lua` | Removed duplicate messages, fixed relative_path |
| `libs/utils.lua` | Fixed relative_path for project directory |
| 6 other scripts | Fixed relative_path for project directory |

### Remaining Items (Future Work)

- Problem 2: Verbose vs Normal mode (not implemented)
- Problem 4: Unclear byte counts in extract-bluesky.lua (not implemented)
- Problem 7: Semantic colors library (proposed but not implemented)

---

## Proposed Enhancement: Expanded Colorization (2026-01-30)

### Issue: Inconsistent Line Colorization

Currently, only icons/emojis are colorized while the rest of the line remains white. This is visually inconsistent and makes the semantic meaning less scannable.

**Current behavior:**
```
⚠️  Skipped older: ./input/similar-different.zip (2025-12-13)
    ↑ yellow    ↑ white text
```

**Intended behavior:**
```
⚠️  Skipped older: ./input/similar-different.zip (2025-12-13)
    ↑ entire line is yellow
```

### Principle: Colorize the Whole Line

When a line has semantic meaning (warning, error, milestone, info), the **entire line** should be colored, not just the icon. This makes the output:
- More scannable (yellow lines = attention, green lines = milestones)
- More consistent (no mixing of colored icons with white text)
- More accessible (color carries meaning beyond the icon)

### Stage Delimiters Should Be Colorful

The stage transition delimiters are currently plain. They should be visually distinct:

**Current:**
```
═══════════════════════════════════════════════════════════════════════════
📁 Stage 1/10: Updating input files from words repository
═══════════════════════════════════════════════════════════════════════════
```

**Proposed:**
```
[magenta]═══════════════════════════════════════════════════════════════════════════[reset]
[green]📁 Stage 1/10:[reset] Updating input files from words repository
[magenta]═══════════════════════════════════════════════════════════════════════════[reset]
```

Or use different colors per stage for visual tracking:

```
[cyan]══════════════════════════ Stage 1/10: Input Files ═════════════════════════[reset]
...
[blue]══════════════════════════ Stage 2/10: Extraction ══════════════════════════[reset]
...
[green]═════════════════════════ Stage 3/10: Processing ══════════════════════════[reset]
```

### Implementation Suggestions

1. **Update all `print()` calls** that use colored icons to color the full line:
   ```lua
   -- Before:
   print(COLOR_YELLOW .. "⚠️  " .. COLOR_RESET .. "Skipped older: " .. path)

   -- After:
   print(COLOR_YELLOW .. "⚠️  Skipped older: " .. path .. COLOR_RESET)
   ```

2. **Create stage delimiter function** in libs/output.lua or run.sh:
   ```bash
   # Bash example
   stage_header() {
       local stage_num="$1"
       local stage_name="$2"
       echo -e "\033[35m════════════════════════════════════════════════════════════════════\033[0m"
       echo -e "\033[92m📁 Stage ${stage_num}/10:\033[0m ${stage_name}"
       echo -e "\033[35m════════════════════════════════════════════════════════════════════\033[0m"
   }
   ```

3. **Semantic line helpers** (extend proposed output.lua):
   ```lua
   function output.warning(msg)
       print(output.YELLOW .. "⚠️  " .. msg .. output.RESET)
   end
   function output.stage_delimiter(num, total, name)
       print(output.MAGENTA .. string.rep("═", 72) .. output.RESET)
       print(output.GREEN .. "📁 Stage " .. num .. "/" .. total .. ":" .. output.RESET .. " " .. name)
       print(output.MAGENTA .. string.rep("═", 72) .. output.RESET)
   end
   ```

### Files to Update

| File | Changes Needed |
|------|----------------|
| `scripts/zip-extractor.lua` | Full-line coloring for warnings |
| `scripts/update-words` | Full-line coloring for sync status |
| `run.sh` | Colorful stage delimiters |
| `libs/utils.lua` | Add semantic output helpers |
| All extractor scripts | Consistent full-line coloring |

## Related Documents

- `issues/completed/7-002-clean-up-run-sh-output.md` — Previous cleanup effort
- `issues/completed/10-014-complete-config-migration-from-input-sources-json.md` — Config warning fix

## Metadata

- **Status**: Completed (partial - core issues fixed, colorization and verbose mode deferred)
- **Created**: 2026-01-30
- **Completed**: 2026-01-30
- **Updated**: 2026-01-30 (added colorization enhancement proposal)
- **Phase**: 7 (Stabilization and Polish)
- **Estimated Complexity**: Medium
- **Affects**: All pipeline output, user experience

## Follow-up Issues

- **7-006**: Implement expanded colorization (full-line colors, stage delimiters) - to be created
- **10-016**: TUI per-stage regeneration options - to be created
