# Issue 002b: Script Integration

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** High
**Dependencies:** 002a (TUI Library Enhancements)

---

## Current Behavior

`issue-splitter.sh` has an "Execute Recommendations" mode that:
1. Parses analysis tables to extract sub-issue recommendations
2. Calls `generate_subissue()` to create skeletal markdown files
3. Skeletal files contain placeholders like "(To be filled in during implementation)"

The script does not have a way to generate complete, implementation-ready issue files. Users must manually flesh out skeletons before Auto-Implement can work effectively.

Additionally, the TUI has no "Generate Complete Issues" option, and no visual feedback mechanisms for auto-enabled dependencies.

---

## Intended Behavior

Integrate the "Generate Complete Issues" processing option into `issue-splitter.sh`:

1. **New TUI menu item** - "Generate Complete Issues" in Processing Options section
2. **Dependency wiring** - Only enabled when mode = Execute Recommendations
3. **Yellow highlight** - Suggested when Execute mode is selected
4. **Prerequisite chaining** - Auto-enables Session Mode with 3x red flash when selected
5. **Claude tool-call generation** - Invokes Claude with Write tool to create complete files
6. **Mid-process pause** - Allows context injection during generation
7. **Validation** - Checks generated files have required sections

---

## Suggested Implementation Steps

### Step 1: Add TUI menu item

In the `interactive_mode_tui()` function, add to processing section:

```bash
menu_add_item "processing" "generate_complete" "Generate Complete Issues" "checkbox" "0" \
    "Claude writes full issue files via tool calls (enables Session Mode)" "g" ""
```

### Step 2: Add dependencies

```bash
# Only enabled for Execute Recommendations mode
menu_add_dependency "generate_complete" "execute" "0" "true" \
    "Only applies to Execute Recommendations mode" "yellow"

# Suggested (yellow) when Execute mode active
menu_add_dependency "generate_complete" "execute" "1" "suggest" \
    "Recommended for complete specifications" "yellow"

# Auto-enable Session Mode when selected
menu_add_prerequisite "generate_complete" "session"
```

### Step 3: Add GENERATE_COMPLETE flag extraction

After menu runs, extract the flag:

```bash
GENERATE_COMPLETE=false
[[ "$(menu_get_value "generate_complete")" == "1" ]] && GENERATE_COMPLETE=true
```

### Step 4: Create `build_generation_prompt()`

```bash
# {{{ build_generation_prompt
build_generation_prompt() {
    local parent_path="$1"
    shift
    local subissues=("$@")

    cat <<'EOF'
You analyzed this issue and recommended sub-issue splits.
Now use the Write tool to create complete issue files.

For each file, include these sections:
- **Current Behavior** - What exists now (infer from parent issue context)
- **Intended Behavior** - Detailed specification
- **Suggested Implementation Steps** - Concrete, numbered, actionable
- **Related Documents** - Parent issue, siblings, relevant code
- **Acceptance Criteria** - Testable checkbox items

Use the Write tool directly to create each file. The tool is available
to you - just write each file with complete, implementation-ready content.

Files to generate:
EOF

    for f in "${subissues[@]}"; do
        echo "- $f"
    done
}
# }}}
```

### Step 5: Create `generate_complete_issues()`

```bash
# {{{ generate_complete_issues
generate_complete_issues() {
    local parent_path="$1"
    shift
    local subissues=("$@")

    local prompt
    prompt=$(build_generation_prompt "$parent_path" "${subissues[@]}")

    log "  Generating complete issue files via Claude..."

    # Continue session, enable Write tool
    if claude --continue --allowedTools Write -p "$prompt"; then
        log "  Generation complete"
    else
        log "  [ERROR] Generation failed, falling back to skeletons"
        return 1
    fi
}
# }}}
```

### Step 6: Modify `execute_recommendations()`

After extracting recommendations, check flag:

```bash
if [[ "$GENERATE_COMPLETE" == true ]]; then
    # Build list of files to generate
    local subissue_files=()
    for rec in "${valid_recommendations[@]}"; do
        IFS='|' read -r id name desc <<< "$rec"
        name=$(echo "$name" | sed 's/^[- ]*//' | sed 's/[- ]*$//' | tr ' ' '-')
        subissue_files+=("${ISSUES_DIR}/${id}-${name}.md")
    done

    # Generate via Claude tool calls
    if ! generate_complete_issues "$issue_path" "${subissue_files[@]}"; then
        # Fallback: create skeletons
        for rec in "${valid_recommendations[@]}"; do
            IFS='|' read -r id name desc <<< "$rec"
            generate_subissue "$issue_path" "$id" "$name" "$desc"
        done
    fi
else
    # Current behavior: create skeletons
    for rec in "${valid_recommendations[@]}"; do
        IFS='|' read -r id name desc <<< "$rec"
        generate_subissue "$issue_path" "$id" "$name" "$desc"
    done
fi
```

### Step 7: Add mid-process pause integration

After generating each N files (or between parent issues):

```bash
if [[ "$GENERATE_COMPLETE" == true ]]; then
    local choice
    choice=$(menu_batch_pause "c:continue" "r:read file" "p:provide context" "s:skip remaining")
    case "$choice" in
        r)
            read -p "File path to read: " extra_file
            # Add to context somehow...
            ;;
        p)
            read -p "Additional context: " extra_context
            # Add to prompt...
            ;;
        s)
            break
            ;;
    esac
fi
```

### Step 8: Create `validate_issue_file()`

```bash
# {{{ validate_issue_file
validate_issue_file() {
    local file="$1"
    local missing=()

    [[ ! -f "$file" ]] && { log "  WARNING: File not created: $file"; return 1; }

    grep -q "^## Current Behavior" "$file" || missing+=("Current Behavior")
    grep -q "^## Intended Behavior" "$file" || missing+=("Intended Behavior")
    grep -q "^## Suggested Implementation" "$file" || missing+=("Implementation Steps")
    grep -q "^## Acceptance Criteria" "$file" || missing+=("Acceptance Criteria")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "  WARNING: $file missing sections: ${missing[*]}"
        return 1
    fi

    log "  Validated: $(basename "$file")"
    return 0
}
# }}}
```

### Step 9: Add validation pass after generation

```bash
# After generate_complete_issues succeeds:
local valid_count=0
local invalid_count=0
for f in "${subissue_files[@]}"; do
    if validate_issue_file "$f"; then
        ((++valid_count))
    else
        ((++invalid_count))
    fi
done
log "  Validation: $valid_count valid, $invalid_count with warnings"
```

### Step 10: Test end-to-end

1. Run `./issue-splitter.sh -I`
2. Select "Execute Recommendations" mode
3. Verify "Generate Complete Issues" appears yellow (suggested)
4. Select "Generate Complete Issues"
5. Verify "Session Mode" auto-enables with 3x red flash
6. Run on test issue with analysis
7. Verify complete files are generated
8. Verify validation reports correctly

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (main script)
- 002-generate-complete-issue-files.md (parent issue)
- 002a-tui-library-enhancements.md (dependency - provides TUI functions)
- Issue 001: Resume Previous Analysis Context (related context features)

---

## Acceptance Criteria

- [ ] "Generate Complete Issues" option appears in TUI Processing Options
- [ ] Option disabled (grayed) when mode ≠ Execute Recommendations
- [ ] Option highlighted yellow when Execute mode selected but option not yet enabled
- [ ] Selecting option auto-enables Session Mode with 3x red flash
- [ ] Claude generates Write tool calls when option enabled
- [ ] Generated files contain all required sections (not placeholders)
- [ ] `validate_issue_file()` reports missing sections
- [ ] Mid-process pause allows context injection
- [ ] Fallback to skeleton generation if Claude fails
- [ ] End-to-end test passes

---

## Notes

*This depends on 002a being complete - the TUI library functions must exist before they can be used.*

*The `--allowedTools Write` flag for Claude CLI may need verification - check current CLI documentation for exact syntax.*

*Fallback to skeletons ensures the script never fails completely - users still get something even if generation fails.*

*Mid-process pause is optional but valuable for complex projects where Claude may need additional context mid-generation.*
