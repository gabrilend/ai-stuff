# Delta-Version Development Guide

This guide documents the conventions, patterns, and best practices for developing Delta-Version and related projects.

## Core Principles

1. **Project-Agnostic**: All scripts work without hardcoding project names
2. **Location Independence**: Scripts run from any directory via `DIR` variable
3. **Dual-Mode Operation**: All utilities support interactive and headless modes
4. **Error Over Fallback**: Prefer explicit errors over silent fallbacks
5. **Immutable Issues**: Issues are tracked progressively, never deleted

---

## Script Conventions

### DIR Variable Pattern

All scripts must define a `DIR` variable at the top:

```bash
#!/bin/bash
# Script description here

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
```

This allows scripts to:
- Run from any working directory
- Accept custom paths via environment variable
- Maintain consistent path resolution

**Usage:**
```bash
# Default directory
./script.sh

# Custom directory
DIR=/custom/path ./script.sh

# Or as argument (if supported)
./script.sh /custom/path
```

### Vimfold Organization

All functions must use vimfolds for code organization:

```bash
# -- {{{ function_name
function function_name() {
    # Function implementation
    local arg1="$1"
    # ...
}
# }}}
```

The format is:
1. Comment line: `# -- {{{ function_name` (name without arguments)
2. Function definition with arguments
3. Function body
4. Closing fold on separate line: `# }}}`

### Interactive Mode Flag

All scripts must support `-I` or `--interactive` flag:

```bash
# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Script Name ==="
    echo "1. Option one"
    echo "2. Option two"
    echo "3. Option three"

    read -p "Select option [1-3]: " choice

    case $choice in
        1) do_option_one ;;
        2) do_option_two ;;
        3) do_option_three ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ main
function main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -I|--interactive)
                run_interactive_mode
                exit 0
                ;;
            # ... other flags
        esac
    done
}
# }}}
```

### Help Message

Every script must have a `--help` option:

```bash
# -- {{{ show_help
function show_help() {
    echo "Usage: script-name.sh [OPTIONS] [ARGUMENTS]"
    echo
    echo "Description of what the script does."
    echo
    echo "Options:"
    echo "  --flag          Description of flag"
    echo "  -I, --interactive  Run in interactive mode"
    echo "  --help          Show this help message"
    echo
    echo "Examples:"
    echo "  script-name.sh --flag value"
    echo "  script-name.sh -I"
}
# }}}
```

### Script Header Comment

Every script should begin with a descriptive header:

```bash
#!/bin/bash
# Brief description of what this script does
# General description of how it accomplishes its purpose (fit for a CEO)

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
```

---

## Issue Management

### Issue File Naming

```
{PHASE}{ID}-{DESCR}.md
```

- **PHASE**: Single digit (1-9)
- **ID**: Three-digit sequential number (001-999)
- **DESCR**: Dash-separated description

Examples:
```
1-001-prepare-repository-structure.md
2-012-generate-unified-gitignore.md
```

### Sub-Issues

For complex issues requiring breakdown:

```
{PHASE}{ID}{INDEX}-{DESCR}.md
```

Where INDEX is alphabetical (a, b, c, etc.):
```
2-012a-template-rendering.md
2-012b-section-generation.md
```

### Issue Lifecycle

1. **Creation**
   - Create issue file following template
   - Add to `docs/table-of-contents.md`
   - Update relevant progress file

2. **In Progress**
   - Update progress file to mark as in_progress
   - Document implementation steps in issue
   - Update related issues as needed

3. **Completion**
   - Verify all success criteria met
   - Add lessons learned to issue
   - Move to `issues/completed/`
   - Update progress file
   - Update related issues
   - Commit to version control

### Required Issue Sections

- **Current Behavior**: What exists now
- **Intended Behavior**: What should exist after
- **Suggested Implementation Steps**: Concrete steps with code
- **Metadata**: Priority, complexity, dependencies
- **Success Criteria**: Measurable completion indicators

---

## Progress Tracking

### Phase Progress Files

Each phase has a progress file at:
```
issues/phase-{N}/progress.md
```

Progress files must include:
- Phase overview and goals
- Issue status (completed, in progress, pending)
- Key achievements
- Next steps
- Quality metrics
- Risk assessment

### Status Indicators

Use these emoji consistently:
- ✅ Completed
- 🔄 In Progress
- 📋 Pending
- 📝 New

### Updating Progress

After completing any issue:
1. Update the phase progress file
2. Update `issues/progress.md` (main progress)
3. Update any affected related issues

---

## Code Quality

### Error Handling

Prefer explicit errors over fallbacks:

```bash
# Good: Explicit error
if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Configuration file not found: $config_file" >&2
    exit 1
fi

# Bad: Silent fallback
config_file="${config_file:-/default/path}"
```

### Output Messages

- Use `echo` for normal output to stdout
- Use `echo ... >&2` for errors to stderr
- Provide context in error messages
- Include file paths and line numbers when relevant

### Exit Codes

- `0`: Success
- `1`: General error
- `2`: Usage/argument error
- Document non-standard exit codes in help message

---

## Testing and Demos

### Phase Demos

Each completed phase should have a demo script:

```
issues/completed/demos/phase-{N}-demo.sh
```

Demo scripts should:
- Display relevant statistics and datapoints
- Show actual outputs (not just descriptions)
- Demonstrate tools from previous phases used in new ways
- Be runnable with a simple bash command

### Demo Structure

```bash
#!/bin/bash
# Phase N Demo: {Title}
# Demonstrates functionality developed in Phase N

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

echo "=== Phase N: {Title} ==="
echo

# Statistics
echo "Statistics:"
echo "  - Issues completed: X"
echo "  - Scripts created: Y"
# ...

# Demonstrations
echo
echo "Demonstrating {feature}..."
# Actual demonstration code

echo
echo "Phase N demo complete."
```

---

## Documentation

### Table of Contents

All documents must be added to:
```
docs/table-of-contents.md
```

Maintain hierarchy and use consistent formatting.

### Document Types

| Directory | Purpose |
|-----------|---------|
| `docs/` | Project documentation |
| `notes/` | Design documents, vision |
| `assets/` | Templates, configurations |
| `issues/` | Issue tracking |

### Cross-References

Link related documents:
```markdown
## Related Documents
- [API Reference](api-reference.md) - Script documentation
- [Issue 012](../issues/012-generate-unified-gitignore.md) - Related issue
```

---

## Git Workflow

### Commit Messages

When committing completed issues:
```
Complete issue {ID}: {Brief description}

- {Change 1}
- {Change 2}
- {Change 3}

Closes #{ID}
```

### Branch Strategy

Delta-Version manages branch isolation for other projects. For delta-version itself:
- Work directly on master branch
- Commit after each completed issue
- Tag phase completions

---

## Interactive Mode Best Practices

### Menu Design

- Use numbered options (1, 2, 3, etc.)
- Keep option count manageable (6-8 max per menu)
- Support index-based selection
- Include exit/back option

### Input Validation

```bash
read -p "Select option [1-6]: " choice

case $choice in
    [1-6]) do_option "$choice" ;;
    q|Q) exit 0 ;;
    *) echo "Invalid selection"; show_menu ;;
esac
```

### Checkbox Selection

For multi-select options, implement checkbox-style:
```bash
# User sees:
# [x] Option 1
# [ ] Option 2
# [x] Option 3
#
# Toggle with number, confirm with Enter
```

---

## Common Patterns

### Project Discovery

Use `list-projects.sh` for consistent project discovery:

```bash
source "$DIR/delta-version/scripts/list-projects.sh"

for project in $(get_project_list_for_integration "abs-paths"); do
    echo "Processing: $project"
done
```

### Pattern Processing

For gitignore or similar pattern work:

```bash
# Parse patterns
while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue  # Skip comments
    [[ -z "$line" ]] && continue         # Skip empty
    # Process pattern
done < "$input_file"
```

### Report Generation

```bash
# -- {{{ generate_report
function generate_report() {
    local output_file="$1"

    cat > "$output_file" <<EOF
REPORT TITLE
============
Generated: $(date)

Section 1
---------
$section1_content

Section 2
---------
$section2_content
EOF
}
# }}}
```
