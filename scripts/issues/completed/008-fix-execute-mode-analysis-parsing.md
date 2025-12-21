# 008 - Fix Execute Mode Analysis Parsing

## Status
- Priority: High
- Completed: 2025-12-21

---

## Current Behavior (Before Fix)

Three issues with the execute recommendations workflow:

1. **"Skip Analyzed" available in Execute mode**
   - The "Skip Analyzed" option was available for all operation modes
   - In Execute mode, this would skip issues WITH analysis - the only
     ones that CAN be executed
   - Result: nothing processable, confusing behavior

2. **Tables under sub-headings not found**
   - `parse_analysis()` stopped at any `## ` heading
   - Claude sometimes places recommendation tables under `## Recommended Sub-Issues`
   - The parser would miss these tables entirely
   - Result: "No sub-issue recommendations found" even when present

3. **Multiple analysis sections caused duplicates**
   - When "skip analyzed" is disabled, issues accumulate multiple analyses
   - Parser was outputting ALL sections concatenated
   - `extract_recommendations()` would find tables from all sections
   - Result: duplicate sub-issue creation attempts

---

## Intended Behavior (After Fix)

1. **"Skip Analyzed" disabled for Execute mode**
   - Added menu dependency: when Execute is selected, Skip Analyzed
     is automatically disabled with explanation
   - User cannot accidentally skip the issues they need to process

2. **Parser continues through sub-headings**
   - Changed from stopping at `## ` to stopping at `---` separator
   - Now captures content from `## Sub-Issue Analysis` through any
     sub-headings until the section ends
   - Tables under `## Recommended Sub-Issues` are now found

3. **Only LAST analysis section used**
   - When multiple sections exist, only the most recent is extracted
   - Older analyses are ignored during execution
   - Prevents duplicate sub-issue creation

---

## Implementation Details

### Dependency Addition (interactive_mode_tui)

```bash
# "Execute Recommendations" mode only processes issues WITH analysis
# Skipping analyzed issues would skip the only ones that can be executed
menu_add_dependency "skip_existing" "execute" "1" "true" \
    "Execute mode requires analysis (would skip processable issues)" "yellow"
```

### parse_analysis() Rewrite

Old logic (sed):
```bash
# Stopped at any ## heading - missed tables under sub-headings
sed -n '/^## Sub-Issue Analysis$/,/^## /p' "$issue_path" | head -n -1
```

New logic (awk):
```bash
# Captures through sub-headings, stops at ---, only outputs LAST section
awk '
    /^## Sub-Issue Analysis/ {
        capturing = 1
        buffer = ""
    }
    capturing {
        if (/^---$/) {
            last_section = buffer  # Save but do not print
            capturing = 0
            buffer = ""
        } else {
            buffer = buffer $0 "\n"
        }
    }
    END {
        if (capturing && buffer != "") {
            print buffer
        } else if (last_section != "") {
            print last_section
        }
    }
'
```

---

## Lessons Learned

1. **Menu dependencies should match semantic intent**
   - Options that don't make sense for a mode should be auto-disabled
   - The dependency system exists for this purpose - use it

2. **Claude's output format varies**
   - Cannot assume tables will be directly under the analysis heading
   - Parser must be flexible about sub-section structure
   - Stop at semantic boundaries (`---`) not syntactic ones (`## `)

3. **Accumulating state needs explicit handling**
   - When data can accumulate (multiple analyses), decide which to use
   - "Most recent" is usually correct for iterative refinement workflows
   - Document the decision in code comments

---

## Related Commits

- `babd3c4c` - Disable Skip Analyzed option when Execute mode is selected
- `71394bda` - Fix parse_analysis to capture tables under sub-headings
- `939439b3` - Only use the LAST analysis section when multiple exist

---

## Testing

Verified fixes with `/mnt/mtwo/.../translation-layer-wow-chat-city-of-chat/issues/201-research-coh-protocol.md`:
- File has 3 analysis sections with tables under `## Recommended Sub-Issues`
- Parser now correctly extracts only the last section
- Table rows are found and can be executed

---

## Notes

These fixes were discovered while initializing a new project and running
the issue-splitter in execute mode. The OB (Original Bug) was "no sub-issue
recommendations found" despite visible tables in the analysis sections.

Root cause chain:
1. Tables were under sub-heading (not directly in analysis section)
2. Parser stopped at sub-heading, never saw tables
3. Additionally, multiple sections would have caused duplicates if found
