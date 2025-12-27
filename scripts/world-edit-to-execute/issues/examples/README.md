# Issue Split Demo: How We Got Here

This directory contains a worked example of manually splitting an issue into sub-issues. The goal is to use this process to inform how `issue-splitter.sh` should automate the same workflow.

---

## The Journey

### 1. Initial Problem Identification

During a conversation about `issue-splitter.sh`, we identified a gap in the pipeline:

```
Analyze → Execute Recommendations → ??? → Auto-Implement
```

"Execute Recommendations" created skeletal issue files with placeholders like "(To be filled in during implementation)". Users had to manually flesh these out before Auto-Implement could work effectively.

### 2. First Issue Created (Original 002)

We created **Issue 002: Elaborate Skeletal Issues Option** - a processing option that would have Claude flesh out the skeletons during the Execute Recommendations step.

Key features:
- Auto-enable Session Mode with visual feedback (3x red flash)
- Yellow highlight as "suggested" option
- Mid-process context injection
- TUI library enhancements (genericizable functions)

### 3. Second Issue Created (Original 005)

Thinking further, we created **Issue 005: Generate Issue Files via Tool Calls** - a different approach where Claude would use Write tool calls to create complete files directly.

Key features:
- Reuse Claude's analysis context (same session)
- Claude generates tool calls, not just text
- Mode chaining (prerequisites auto-enable)
- Validation of generated files

### 4. Recognizing Overlap

We noticed Issues 002 and 005 had the same goal (close the skeleton→specification gap) but different approaches. Rather than maintain two overlapping issues, we merged them.

### 5. Combined Issue Created (Current 002)

The merged **Issue 002: Generate Complete Issue Files** combines:
- TUI library enhancements from original 002
- Tool-call approach from original 005
- All considerations from both

### 6. Splitting the Combined Issue

The combined issue is large and contains two distinct work streams:
- **Part A**: TUI library enhancements (genericizable, reusable across scripts)
- **Part B**: Script-specific integration (issue-splitter.sh changes)

We're now manually splitting this into sub-issues to:
1. Make each piece independently implementable
2. Document the split process as an example
3. Inform how `issue-splitter.sh` should automate this workflow

---

## Stage Directories

Each stage directory captures the state of the issue(s) at a point in the split process:

| Stage | Description | Contents |
|-------|-------------|----------|
| stage-0 | Original combined issue | 002-generate-complete-issue-files.md |
| stage-1 | After analysis | 002 with analysis section appended |
| stage-2 | After execute recommendations | 002 + skeletal 002a + skeletal 002b |
| stage-3 | After generate complete | 002 (parent) + complete 002a + complete 002b |

---

## What This Teaches Us

By doing this manually, we observe:

1. **What context is needed** - To split well, you need to understand the issue deeply
2. **How sub-issues relate** - Dependencies, shared context, execution order
3. **What makes a good skeleton** - ID, name, brief description from parent
4. **What makes a complete issue** - All sections filled with actionable specifics
5. **How the parent should change** - Becomes a tracker/overview, references children

This informs the prompts and logic for `issue-splitter.sh`.

---

## Observations from Each Stage

### Stage 0 → Stage 1 (Analysis)

**Input:** Original unsplit issue (11.6KB)
**Output:** Same issue with analysis section appended (+1.2KB)

**What the analysis adds:**
- Recommendation table with ID, name, description for each sub-issue
- Rationale explaining why splitting makes sense
- Execution order (dependency information)

**Insight for automation:** The analysis prompt should explicitly ask for:
- Markdown table format (parseable)
- Dependency information between sub-issues
- Rationale (helps validate the split makes sense)

### Stage 1 → Stage 2 (Execute Recommendations)

**Input:** Analyzed issue
**Output:** Parent issue + 2 skeletal sub-issues (~0.7KB each)

**What skeletons contain:**
- ID and title derived from recommendation table
- Placeholder sections: "(To be filled in during implementation)"
- Dependency noted in header
- Link back to parent issue

**Insight for automation:** Skeletons are cheap to generate - just string templates. The value is in organizing the structure. But they're useless for implementation.

### Stage 2 → Stage 3 (Generate Complete)

**Input:** Parent + 2 skeletons (~0.7KB each)
**Output:** Parent + 2 complete issues (~6.5KB, ~8.5KB)

**What complete issues contain:**
- Current Behavior: actual description of existing state
- Intended Behavior: detailed specification with code examples
- Implementation Steps: numbered, concrete, referencing specific functions
- Acceptance Criteria: testable checkboxes
- Notes: context, caveats, related concerns

**Insight for automation:** This is where Claude's context is crucial. The complete issues reference:
- Specific function names from the parent
- Lua code patterns from the existing TUI library
- Dependencies between siblings
- Related issues by number

Without retained context, Claude would have to re-read everything. With session mode, it already knows.

---

## Size Comparison

| Stage | Files | Total Size | Notes |
|-------|-------|------------|-------|
| 0 | 1 | 11.6KB | Original combined issue |
| 1 | 1 | 12.9KB | +analysis section |
| 2 | 3 | 14.4KB | +2 skeletons (~1.4KB) |
| 3 | 3 | 28.0KB | Complete sub-issues (~15KB added) |

The "Generate Complete" step nearly doubles the content - that's where the real value is created.

---

## Key Design Decisions for issue-splitter.sh

1. **Session mode is essential** for Generate Complete - context must flow from analysis through generation

2. **Skeletons are optional** - could go directly from analysis to complete generation if session is maintained

3. **Validation matters** - generated files should be checked for required sections

4. **Fallback needed** - if generation fails, create skeletons rather than nothing

5. **The prompt is critical** - must explicitly request markdown table, dependencies, all required sections
