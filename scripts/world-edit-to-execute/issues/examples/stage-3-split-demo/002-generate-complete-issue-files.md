# Issue 002: Generate Complete Issue Files

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** High
**Dependencies:** None

---

## Current Behavior

The "Execute Recommendations" step:
1. Parses the analysis table from analyzed issues
2. Calls `generate_subissue()` which creates skeletal markdown templates
3. Templates contain placeholders like "(To be filled in during implementation)"

The result is bureaucratic scaffolding without substance. Users must manually flesh out each issue file before "Auto-Implement" can meaningfully execute them.

Additionally, the analysis context is discarded after recommendations are extracted - Claude's understanding of the problem space is lost.

---

## Intended Behavior

Add a processing option: **"Generate Complete Issues"** that transforms skeletons into full specifications using Claude's retained context and tool-calling capability.

### The Pipeline

```
Analyze → [rich context, Claude understands the problem]
    ↓
Execute Recommendations → [identifies sub-issues to create]
    ↓
Generate Complete Issues → [Claude writes files via Write tool calls]
    ↓
Auto-Implement → [has detailed specs, produces quality code]
```

Each step builds on the previous. No manual gap-filling required.

### Behavior When Selected:

1. **Auto-enables Session Mode** - When selected, "Session Mode" automatically enables and flashes red 3 times (visual feedback even if cursor is elsewhere). Context must accumulate across issue generation.

2. **Yellow highlight as suggestion** - When "Execute Recommendations" mode is selected, this option appears highlighted in yellow (suggested but not forced) until explicitly de-selected.

3. **Disabled for other modes** - Grayed out when mode ≠ Execute Recommendations.

4. **Claude generates Write tool calls** - For each sub-issue:
   - Continue the analysis session (`claude --continue`)
   - Ask Claude to generate Write tool calls for complete issue files
   - Claude decides content based on accumulated context
   - Files are written directly by Claude's tool use

5. **Context accumulation** - Because session mode is enabled, Claude remembers:
   - The parent issue analysis
   - Previously generated sibling sub-issues
   - Any additional context read during the process

6. **Mid-process context injection** - Allow user to pause and add context:
   ```
   [c]ontinue | [r]ead additional file | [p]rovide context | [s]kip remaining
   ```

7. **Validation** - After generation:
   - Check required sections exist (Current Behavior, Intended Behavior, Implementation Steps, Acceptance Criteria)
   - Warn if any section is empty or placeholder-like
   - Report generation summary

---

## The Generation Prompt

After Execute Recommendations identifies sub-issues, send to Claude:

```
You've just analyzed these issues and recommended splitting them into sub-issues.
Now I need you to create the actual issue files.

For each sub-issue, generate a Write tool call that creates a complete issue file with:

1. **Current Behavior** - What exists now (infer from parent issue context)
2. **Intended Behavior** - Detailed specification of what this sub-issue should achieve
3. **Suggested Implementation Steps** - Concrete, actionable steps (not placeholders)
4. **Related Documents** - Parent issue, sibling sub-issues, relevant code paths
5. **Acceptance Criteria** - Testable conditions for completion

Use the context from your analysis to make these specifications precise and useful.
The goal is issue files that an implementer (human or AI) can execute without
needing additional clarification.

Sub-issues to create:
- 103a-parse-header.md
- 103b-validate-structure.md
- 103c-extract-fields.md
```

### Output

Claude generates Write tool calls:

```
<tool_call>
Write("/path/to/issues/103a-parse-header.md", "# Issue 103a: Parse Header\n\n**Phase:** 1...\n\n## Current Behavior\n\nThe parser currently reads...")
</tool_call>
```

Each file is complete and implementation-ready.

---

## Mode Chaining

Selecting downstream modes can auto-enable prerequisites:

```
[ ] Analyze Issues
[ ] Execute Recommendations
[x] Generate Complete Issues  ← auto-enables Execute + Analyze + Session Mode
[ ] Auto-Implement            ← could auto-enable full pipeline
```

This creates one-click pipelines: select the end goal, prerequisites chain automatically.

---

## Suggested Implementation Steps

### Part A: TUI Library Enhancements (genericizable)

These features should be added to the menu TUI library for reuse across scripts:

1. **Auto-enable with visual feedback**:
   ```lua
   menu_force_enable(item_id, flash_count, flash_color)
   -- e.g., menu_force_enable("session", 3, "red")
   ```

2. **Suggested state (yellow highlight)** - New dependency type:
   ```lua
   menu_add_dependency(item, trigger, trigger_value, "suggest", message, "yellow")
   -- Shows yellow when trigger condition met AND item is not yet selected
   ```

3. **Mid-process interactive pause**:
   ```lua
   menu_batch_pause(options_table)
   -- e.g., {c = "continue", r = "read file", p = "provide context", s = "skip"}
   -- Returns selected option key
   ```

4. **Item flash/pulse animation**:
   ```lua
   menu_flash_item(item_id, count, color, interval_ms)
   ```

5. **Mode chaining / prerequisite auto-enable**:
   ```lua
   menu_add_prerequisite(item_id, prerequisite_id)
   -- When item selected, prerequisite auto-enables (with flash feedback)
   ```

### Part B: Script-Specific Implementation

1. **Add TUI menu item**:
   ```bash
   menu_add_item "processing" "generate_complete" "Generate Complete Issues" "checkbox" "0" \
       "Claude writes full issue files via tool calls (enables Session Mode)" "g" ""
   ```

2. **Add dependencies**:
   ```bash
   menu_add_dependency "generate_complete" "execute" "0" "true" \
       "Only applies to Execute Recommendations mode" "yellow"
   menu_add_prerequisite "generate_complete" "session"
   ```

3. **Build generation prompt**:
   ```bash
   build_generation_prompt() {
       local parent_path="$1"
       shift
       local subissues=("$@")

       cat <<'EOF'
   You analyzed this issue and recommended sub-issue splits.
   Now generate Write tool calls to create complete issue files.

   For each file, include:
   - Current Behavior (inferred from context)
   - Intended Behavior (detailed specification)
   - Implementation Steps (concrete, actionable)
   - Acceptance Criteria (testable)

   Files to generate:
   EOF

       for f in "${subissues[@]}"; do
           echo "- $f"
       done
   }
   ```

4. **Invoke Claude with tool-use**:
   ```bash
   generate_complete_issues() {
       local parent_path="$1"
       shift
       local subissues=("$@")

       local prompt=$(build_generation_prompt "$parent_path" "${subissues[@]}")

       # Continue session, enable Write tool
       claude --continue --allowedTools Write -p "$prompt"
   }
   ```

5. **Modify execute_recommendations()** - After identifying sub-issues:
   ```bash
   if [[ "$GENERATE_COMPLETE" == true ]]; then
       generate_complete_issues "$issue_path" "${subissue_files[@]}"
   else
       # Current behavior: create skeletons
       for rec in "${recommendations[@]}"; do
           generate_subissue ...
       done
   fi
   ```

6. **Add mid-process pause** - After each N issues or on keypress, offer context injection.

7. **Validate generated files**:
   ```bash
   validate_issue_file() {
       local file="$1"
       local missing=()

       grep -q "^## Current Behavior" "$file" || missing+=("Current Behavior")
       grep -q "^## Intended Behavior" "$file" || missing+=("Intended Behavior")
       grep -q "^## Suggested Implementation" "$file" || missing+=("Implementation Steps")
       grep -q "^## Acceptance Criteria" "$file" || missing+=("Acceptance Criteria")

       if [[ ${#missing[@]} -gt 0 ]]; then
           log "  WARNING: Missing sections: ${missing[*]}"
       fi
   }
   ```

---

## TUI Visual Behavior Summary

| State | "Generate Complete Issues" Appearance |
|-------|---------------------------------------|
| Mode ≠ Execute | Disabled (grayed out, unselectable) |
| Mode = Execute, option = off | Yellow highlight (suggested) |
| Mode = Execute, option = on | Normal selected, Session Mode auto-enabled with 3x red flash |

---

## Why Tool Calls?

Two approaches were considered:

| Aspect | Script-controlled | Tool-call approach |
|--------|-------------------|-------------------|
| How | Claude outputs text, script writes | Claude generates Write tool calls |
| Control | Script controls format | Claude controls format |
| Coherence | Per-file prompts | Single prompt, Claude sees all siblings |
| Agency | Script decides when to write | Claude decides content and writes |

**Tool-call approach chosen** because:
- Claude retains full context when deciding what to write
- Single prompt for all sibling issues = more coherent specifications
- Claude can reference earlier siblings when writing later ones
- Simpler script logic (just invoke Claude and let it write)

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh`
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` (TUI menu system - Part A enhancements)
- `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua` (core TUI rendering - flash/animation)
- Issue 001: Resume Previous Analysis Context (per-issue session persistence)
- Issue 003: Flash Disabled Items (TUI feedback patterns)
- Issue 004: Scrollbar for Lists and Content Preview

---

## Sub-Issues (if split)

Consider splitting:
- **002a**: TUI Library Enhancements (Part A) - genericizable menu features
- **002b**: Script Integration (Part B) - issue-splitter specific implementation

---

## Acceptance Criteria

### TUI Library
- [ ] `menu_force_enable()` function with flash feedback
- [ ] Suggested dependency type (yellow highlight)
- [ ] `menu_batch_pause()` for mid-process interaction
- [ ] `menu_flash_item()` animation function
- [ ] Mode chaining / prerequisite auto-enable

### Script Integration
- [ ] "Generate Complete Issues" processing option in TUI
- [ ] Option disabled when mode ≠ Execute Recommendations
- [ ] Option highlighted yellow (suggested) when Execute mode selected
- [ ] Selecting option auto-enables Session Mode with 3x red flash
- [ ] Claude generates Write tool calls for each sub-issue
- [ ] Generated files contain complete specifications (not placeholders)
- [ ] All required sections validated after generation
- [ ] User can inject additional context mid-process
- [ ] Generation summary reports success/warnings for each file
- [ ] Graceful fallback if Claude fails (create skeleton instead)

---

## Notes

*This transforms issue-splitter from a scaffolding tool into a specification generator. The output becomes directly actionable by Auto-Implement or human developers.*

*Key insight: Claude's analysis context is valuable. Discarding it after extracting a table of recommendations wastes understanding. By continuing the conversation, we convert understanding into specification.*

*"Bulletproof" means: given a high-level task description, the pipeline produces implementation-ready specifications without human intervention in the middle. Humans review at the end, not in the gaps.*

*The 3x red flash on session mode is unusual UX but serves as a clear signal that a dependency was auto-satisfied. Consider whether this should be configurable.*

*Mid-process context injection addresses cases where Claude realizes it needs information not yet in context (e.g., "I need to see the database schema to write implementation steps").*

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-26 00:35*

This issue contains two distinct work streams that can be implemented independently:

### Recommendation: Split

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 002a | tui-library-enhancements | None | Add genericizable menu functions: force_enable, suggested state, batch_pause, flash_item, prerequisite chaining |
| 002b | script-integration | 002a | Integrate "Generate Complete Issues" option into issue-splitter.sh using the TUI library features |

### Rationale

1. **Different codebases** - 002a modifies `libs/lua-menu.sh` and `libs/tui.lua`; 002b modifies `issue-splitter.sh`

2. **Independent implementation** - TUI library features can be built and tested without issue-splitter changes; script integration depends on TUI features being available

3. **Reusability** - 002a features benefit all scripts using the TUI library, not just issue-splitter

4. **Clear dependency** - 002b depends on 002a (must implement library features before using them in script)

### Execution Order

```
002a (TUI Library) → 002b (Script Integration)
```

002a should be completed first as 002b depends on its features.

---

## Generated Sub-Issues

*Auto-generated on 2025-12-26 00:40*

- 002a-tui-library-enhancements.md
- 002b-script-integration.md
