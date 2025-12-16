# Issue Template

This document provides the standard template for creating new issues in the Delta-Version project.

## Naming Convention

Issue files follow this naming pattern:
```
{PHASE}{ID}-{DESCR}.md
```

Where:
- **{PHASE}**: Phase number the issue belongs to (0-9)
- **{ID}**: Sequential 3-digit ID number (001-999)
- **{DESCR}**: Dash-separated short description

### Examples
```
1-001-prepare-repository-structure.md    # Phase 1, Issue 001
2-012-generate-unified-gitignore.md      # Phase 2, Issue 012
3-028-foundation-demo-script.md          # Phase 3, Issue 028
```

### Sub-Issues
For large features requiring breakdown:
```
{PHASE}{ID}{INDEX}-{DESCR}.md
```

Where **{INDEX}** is an alphabetical character (a, b, c, etc.):
```
2-012a-template-rendering-engine.md
2-012b-section-generation.md
2-012c-backup-management.md
```

---

## Template Structure

```markdown
# Issue {PHASE}{ID}: {Title}

## Current Behavior

{Describe the current state of the system. What exists? What doesn't work?
Be specific about observable behaviors and limitations.}

### Current Issues
- {Specific problem 1}
- {Specific problem 2}
- {Specific problem 3}

## Intended Behavior

{Describe what the system should do after this issue is resolved.}

1. **{Feature 1}**: {Description}
2. **{Feature 2}**: {Description}
3. **{Feature 3}**: {Description}

## Suggested Implementation Steps

### 1. {Step Title}
\`\`\`bash
# -- {{{ function_name
function function_name() {
    # {Implementation outline}
}
# }}}
\`\`\`

### 2. {Step Title}
{Description of the step and any code examples}

### 3. {Step Title}
{Continue with remaining steps}

## Implementation Details

{Any additional details, data structures, configuration formats,
or technical specifications needed for implementation.}

## Related Documents
- `{related-issue}.md` - {Description of relationship}
- `{related-doc}.md` - {Description of relationship}

## Tools Required
- {Tool or dependency 1}
- {Tool or dependency 2}
- {Tool or dependency 3}

## Metadata
- **Priority**: {High/Medium/Low}
- **Complexity**: {Low/Medium/Medium-High/High}
- **Dependencies**: {Issue numbers or "None"}
- **Impact**: {Brief description of impact on project}

## Success Criteria
- {Measurable criterion 1}
- {Measurable criterion 2}
- {Measurable criterion 3}
- {Criterion that indicates the issue is complete}
```

---

## Required Sections

Every issue MUST contain:

| Section | Purpose |
|---------|---------|
| **Current Behavior** | What exists now, what's broken |
| **Intended Behavior** | What should exist after completion |
| **Suggested Implementation Steps** | Concrete steps with code examples |
| **Metadata** | Priority, complexity, dependencies |
| **Success Criteria** | Measurable completion indicators |

## Optional Sections

| Section | When to Include |
|---------|-----------------|
| **Implementation Details** | Complex data structures or configs |
| **Related Documents** | Cross-references to other issues/docs |
| **Tools Required** | External dependencies needed |
| **Risk Assessment** | For high-complexity issues |

---

## Code Example Guidelines

### Use Vimfolds
All function examples should use vimfold syntax:
```bash
# -- {{{ function_name
function function_name() {
    # implementation
}
# }}}
```

### Show DIR Pattern
Scripts should demonstrate the DIR variable convention:
```bash
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
```

### Include Interactive Mode
When applicable, show both interactive and headless usage:
```bash
# Headless mode
./script.sh --flag value

# Interactive mode
./script.sh -I
```

---

## Issue Lifecycle

### Creation
1. Determine phase and get next available ID
2. Create file with proper naming convention
3. Fill in all required sections
4. Add to `docs/table-of-contents.md`

### In Progress
1. Read and understand the issue fully
2. Update progress.md to mark as in_progress
3. Document steps taken in the issue file
4. Keep related issues updated

### Completion
1. Verify all success criteria are met
2. Update the issue with lessons learned
3. Move to `issues/completed/` directory
4. Update progress.md to mark as completed
5. Update any related issues
6. Commit changes to version control

---

## Example: Minimal Issue

```markdown
# Issue 029: Add Verbose Flag to List Projects

## Current Behavior

The `list-projects.sh` script outputs project information but provides no detailed
output option for debugging or detailed inspection.

## Intended Behavior

Add a `--verbose` flag that outputs additional information:
1. **Project Score**: Show the detection score for each project
2. **Characteristics**: Display which characteristics were detected
3. **Timing**: Show processing time for discovery

## Suggested Implementation Steps

### 1. Add Verbose Flag Handling
\`\`\`bash
# -- {{{ parse_verbose_flag
function parse_verbose_flag() {
    [[ "$1" == "--verbose" || "$1" == "-v" ]] && VERBOSE=true
}
# }}}
\`\`\`

### 2. Update Output Functions
Add verbose information to existing output functions.

## Metadata
- **Priority**: Low
- **Complexity**: Low
- **Dependencies**: None
- **Impact**: Improved debugging and user experience

## Success Criteria
- `--verbose` and `-v` flags are recognized
- Verbose output includes score and characteristics
- Non-verbose mode remains unchanged
- Help text documents new flag
```

---

## Anti-Patterns to Avoid

1. **Vague descriptions**: "Make it better" - be specific
2. **Missing success criteria**: How do you know when you're done?
3. **No code examples**: Implementation steps should be concrete
4. **Orphaned issues**: Always link to related documents
5. **Unbounded scope**: Break large issues into sub-issues
