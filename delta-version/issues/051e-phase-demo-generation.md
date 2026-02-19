# Issue 051e: Phase Demo Generation

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Medium
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)
**Dependencies**: Issue 051d

---

## Current Behavior

No automated method exists to generate phase demonstration scripts from completed issues. Phase demos must be written entirely by hand, requiring:

1. Understanding of what each phase accomplished
2. Knowledge of how to invoke project utilities
3. Time to write meaningful demonstrations
4. Ongoing maintenance as the project evolves

---

## Intended Behavior

Create a module that generates phase demonstration scripts:

1. **Analyzes completed issues** to understand phase capabilities
2. **Identifies entry points** and runnable utilities
3. **Generates demo scripts** that showcase phase functionality
4. **Creates visual output** where possible (TUI, browser, images)
5. **Integrates with run-demo.sh** for unified execution

### Phase Demo Philosophy

From CLAUDE.md:
> "Phase demos are not just a development artifact - they are part of the deliverable product. They should be consistently high quality, showing off all the features in the main project with (ideally) feature parity."

```
┌─────────────────────────────────────────────────────────────────┐
│                    Phase Demo Generation                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────┐                      │
│  │ Input:                               │                      │
│  │ - Completed issues for phase         │                      │
│  │ - Entry points (scripts, main files) │                      │
│  │ - Project utilities                  │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Capability Extraction:               │                      │
│  │ - What does this phase enable?       │                      │
│  │ - What utilities were created?       │                      │
│  │ - What can be demonstrated?          │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Demo Script Generation:              │                      │
│  │ - Header with description            │                      │
│  │ - Setup/prerequisites                │                      │
│  │ - Demonstration commands             │                      │
│  │ - Expected output comments           │                      │
│  │ - Cleanup                            │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Output Types:                        │                      │
│  │ - Terminal output (statistics)       │                      │
│  │ - TUI demonstration                  │                      │
│  │ - File generation                    │                      │
│  │ - Visual (browser, images)           │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Output: issues/completed/demos/      │                      │
│  │         phase-N-demo.sh              │                      │
│  └──────────────────────────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Extract Phase Capabilities

```bash
# -- {{{ extract_phase_capabilities
# Extracts demonstrable capabilities from phase issues
# Returns: JSON with capabilities
extract_phase_capabilities() {
    local phase_num="$1"
    local completed_dir="$2"
    local project_dir="$3"

    local capabilities=()

    # Read all completed issues for this phase
    for issue_file in "$completed_dir/${phase_num}"*.md; do
        [[ -f "$issue_file" ]] || continue

        # Extract issue type
        local issue_type
        issue_type=$(grep "^\*\*Type\*\*:" "$issue_file" | sed 's/.*: //')

        # Extract files changed (potential entry points)
        local files
        files=$(sed -n '/^## Files Changed/,/^##/p' "$issue_file" | \
            grep '^\- `' | sed 's/^- `//;s/`$//')

        # Extract title for description
        local title
        title=$(grep "^# Issue" "$issue_file" | sed 's/^# Issue [^:]*: //')

        # Look for executable scripts or main files
        for file in $files; do
            local full_path="$project_dir/$file"
            if [[ -f "$full_path" ]]; then
                case "$file" in
                    *.sh)
                        capabilities+=("{\"type\": \"script\", \"path\": \"$file\", \"title\": \"$title\"}")
                        ;;
                    *main*.lua|*init*.lua)
                        capabilities+=("{\"type\": \"lua_main\", \"path\": \"$file\", \"title\": \"$title\"}")
                        ;;
                    *.lua)
                        # Check if it has a runnable main block
                        if grep -q "^-- Main\|^if arg\[0\]" "$full_path" 2>/dev/null; then
                            capabilities+=("{\"type\": \"lua_script\", \"path\": \"$file\", \"title\": \"$title\"}")
                        fi
                        ;;
                esac
            fi
        done
    done

    printf '%s\n' "${capabilities[@]}" | jq -s '.'
}
# }}}
```

### 2. Identify Entry Points

```bash
# -- {{{ find_project_entry_points
# Finds all runnable entry points in the project
find_project_entry_points() {
    local project_dir="$1"

    cd "$project_dir" || return 1

    echo "["
    local first=true

    # Find shell scripts
    while IFS= read -r script; do
        [[ -x "$script" ]] || continue
        [[ "$first" == true ]] || echo ","
        first=false

        local desc
        desc=$(head -5 "$script" | grep -E '^#[^!]' | head -1 | sed 's/^# //')

        printf '  {"type": "bash", "path": "%s", "description": "%s", "executable": true}' \
            "$script" "$desc"
    done < <(find . -name "*.sh" -type f | grep -v node_modules | head -20)

    # Find Lua scripts with main blocks
    while IFS= read -r script; do
        [[ "$first" == true ]] || echo ","
        first=false

        local desc
        desc=$(head -5 "$script" | grep -E '^--[^-]' | head -1 | sed 's/^-- //')

        printf '  {"type": "lua", "path": "%s", "description": "%s", "executable": false}' \
            "$script" "$desc"
    done < <(grep -l "^if arg\[0\]\|^-- Main" *.lua */*.lua 2>/dev/null | head -10)

    echo ""
    echo "]"
}
# }}}
```

### 3. Generate Demo Script Content

```bash
# -- {{{ generate_demo_script
# Generates a phase demo script
generate_demo_script() {
    local phase_num="$1"
    local phase_name="$2"
    local capabilities="$3"
    local entry_points="$4"
    local project_name="$5"

    cat << 'HEADER'
#!/bin/bash
# =============================================================================
HEADER

    cat << EOF
# Phase $phase_num Demo: $phase_name
# Project: $project_name
#
# This script demonstrates the capabilities developed in Phase $phase_num.
# Generated automatically by Issue 051 (Git Documentation Generator)
#
# Usage: ./phase-${phase_num}-demo.sh [--headless]
# =============================================================================

set -euo pipefail

# -- {{{ Configuration
DIR="\${DIR:-\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../../.." && pwd)}"
HEADLESS=\${HEADLESS:-false}
[[ "\${1:-}" == "--headless" ]] && HEADLESS=true
# }}}

# -- {{{ Helper Functions
print_header() {
    echo ""
    echo "=============================================="
    echo "\$1"
    echo "=============================================="
    echo ""
}

print_section() {
    echo ""
    echo "--- \$1 ---"
    echo ""
}

pause_if_interactive() {
    if [[ "\$HEADLESS" != true ]]; then
        echo ""
        read -p "Press Enter to continue..." -r
    fi
}
# }}}

# -- {{{ Main Demo
main() {
    print_header "Phase $phase_num: $phase_name"

    echo "This demo showcases the capabilities developed in Phase $phase_num."
    echo ""
    echo "Capabilities demonstrated:"
EOF

    # List capabilities
    echo "$capabilities" | jq -r '.[] | "    - \(.title)"' | sort -u

    cat << 'EOF'

    pause_if_interactive

EOF

    # Generate demo sections for each capability
    local section_num=1
    echo "$capabilities" | jq -c '.[]' | sort -u | while read -r cap; do
        local cap_type cap_path cap_title
        cap_type=$(echo "$cap" | jq -r '.type')
        cap_path=$(echo "$cap" | jq -r '.path')
        cap_title=$(echo "$cap" | jq -r '.title')

        cat << EOF
    # -- {{{ Demo $section_num: $cap_title
    print_section "Demo $section_num: $cap_title"

EOF

        case "$cap_type" in
            script)
                cat << EOF
    echo "Running: $cap_path"
    echo ""

    # Show script help if available
    if "\$DIR/$cap_path" --help 2>/dev/null | head -5; then
        echo ""
    fi

    # Run with sample arguments (customize as needed)
    # "\$DIR/$cap_path" [ARGS]
    echo "[Demo would run: $cap_path]"
    echo "[Customize this section with appropriate arguments]"

EOF
                ;;
            lua_main|lua_script)
                cat << EOF
    echo "Running: lua $cap_path"
    echo ""

    # Run Lua script
    # cd "\$DIR" && lua "$cap_path" [ARGS]
    echo "[Demo would run: lua $cap_path]"
    echo "[Customize this section with appropriate arguments]"

EOF
                ;;
        esac

        cat << EOF
    pause_if_interactive
    # }}}

EOF
        ((section_num++))
    done

    # Statistics section
    cat << 'EOF'
    # -- {{{ Statistics
    print_section "Phase Statistics"

    echo "Issues completed in this phase:"
EOF

    cat << EOF
    ls -1 "\$DIR/issues/completed/${phase_num}"*.md 2>/dev/null | wc -l | xargs echo "  Total issues:"

    echo ""
    echo "Files created/modified:"
    # Count files associated with phase issues
    grep -h "^\- \\\`" "\$DIR/issues/completed/${phase_num}"*.md 2>/dev/null | wc -l | xargs echo "  Total files:"

    pause_if_interactive
    # }}}

EOF

    # Footer
    cat << 'EOF'
    print_header "Demo Complete"
    echo "Phase demo finished successfully."
    echo ""
}

# Run main
main "$@"
EOF
}
# }}}
```

### 4. Main Generation Function

```bash
# -- {{{ generate_phase_demos
# Generates demo scripts for all phases
generate_phase_demos() {
    local roadmap_json="$1"
    local output_dir="$2"
    local project_dir="$3"

    local project_name
    project_name=$(basename "$project_dir")

    local demos_dir="$output_dir/issues/completed/demos"
    mkdir -p "$demos_dir"

    # Get entry points
    local entry_points
    entry_points=$(find_project_entry_points "$project_dir")

    # Generate demo for each phase
    echo "$roadmap_json" | jq -c '.phases[]' | while read -r phase; do
        local phase_num phase_name
        phase_num=$(echo "$phase" | jq -r '.number')
        phase_name=$(echo "$phase" | jq -r '.name')

        log "Generating demo for Phase $phase_num: $phase_name"

        # Extract capabilities for this phase
        local capabilities
        capabilities=$(extract_phase_capabilities "$phase_num" "$output_dir/issues/completed" "$project_dir")

        # Skip if no capabilities found
        if [[ $(echo "$capabilities" | jq 'length') -eq 0 ]]; then
            log "No demonstrable capabilities found for Phase $phase_num, generating stub"
            capabilities='[{"type": "stub", "path": "", "title": "Phase capabilities"}]'
        fi

        # Generate demo script
        local demo_script
        demo_script=$(generate_demo_script "$phase_num" "$phase_name" "$capabilities" "$entry_points" "$project_name")

        # Write script
        local demo_file="$demos_dir/phase-${phase_num}-demo.sh"
        echo "$demo_script" > "$demo_file"
        chmod +x "$demo_file"

        log "Generated: $demo_file"
    done

    # Generate run-demo.sh if it doesn't exist
    generate_demo_runner "$demos_dir" "$roadmap_json"
}
# }}}
```

### 5. Demo Runner Generation

```bash
# -- {{{ generate_demo_runner
# Generates the main run-demo.sh script
generate_demo_runner() {
    local demos_dir="$1"
    local roadmap_json="$2"

    local runner_file="$(dirname "$demos_dir")/../../run-demo.sh"

    # Don't overwrite if exists
    if [[ -f "$runner_file" ]]; then
        log "run-demo.sh exists, skipping"
        return
    fi

    local phase_count
    phase_count=$(echo "$roadmap_json" | jq '.phases | length')

    cat << EOF > "$runner_file"
#!/bin/bash
# =============================================================================
# Demo Runner
# Runs phase demonstration scripts
#
# Usage: ./run-demo.sh [phase_number]
#        ./run-demo.sh --list
#        ./run-demo.sh --all
# =============================================================================

set -euo pipefail

DIR="\${DIR:-\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)}"
DEMOS_DIR="\$DIR/issues/completed/demos"

show_menu() {
    echo "Available Phase Demos:"
    echo ""
    for i in \$(seq 1 $phase_count); do
        local demo="\$DEMOS_DIR/phase-\${i}-demo.sh"
        if [[ -f "\$demo" ]]; then
            local desc=\$(head -5 "\$demo" | grep "^# Phase" | head -1)
            echo "  [\$i] \$desc"
        fi
    done
    echo ""
    echo "Enter phase number (1-$phase_count) or 'q' to quit:"
}

run_demo() {
    local phase="\$1"
    local demo="\$DEMOS_DIR/phase-\${phase}-demo.sh"

    if [[ -f "\$demo" ]]; then
        "\$demo"
    else
        echo "Demo not found: \$demo"
        exit 1
    fi
}

case "\${1:-}" in
    --list)
        show_menu
        ;;
    --all)
        for i in \$(seq 1 $phase_count); do
            run_demo "\$i"
        done
        ;;
    [1-9]*)
        run_demo "\$1"
        ;;
    *)
        show_menu
        read -p "> " choice
        [[ "\$choice" == "q" ]] && exit 0
        run_demo "\$choice"
        ;;
esac
EOF

    chmod +x "$runner_file"
    log "Generated: $runner_file"
}
# }}}
```

---

## Output Examples

### phase-1-demo.sh

```bash
#!/bin/bash
# =============================================================================
# Phase 1 Demo: Foundation
# Project: delta-version
#
# This script demonstrates the capabilities developed in Phase 1.
# Generated automatically by Issue 051 (Git Documentation Generator)
# =============================================================================

set -euo pipefail

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

print_header() {
    echo ""
    echo "=============================================="
    echo "$1"
    echo "=============================================="
}

main() {
    print_header "Phase 1: Foundation"

    echo "Capabilities demonstrated:"
    echo "  - Initial project setup"
    echo "  - Core configuration"
    echo "  - Basic CLI interface"

    # Demo 1: Configuration
    print_section "Demo 1: Configuration"
    echo "Showing configuration file:"
    cat "$DIR/config/default.conf" | head -20

    # Demo 2: CLI
    print_section "Demo 2: CLI Interface"
    "$DIR/scripts/main.sh" --help

    # Statistics
    print_section "Phase Statistics"
    echo "Issues completed: $(ls -1 "$DIR/issues/completed/1"*.md | wc -l)"

    print_header "Demo Complete"
}

main "$@"
```

---

## Acceptance Criteria

- [ ] Extracts capabilities from completed phase issues
- [ ] Identifies entry points (scripts, main files)
- [ ] Generates executable demo scripts for each phase
- [ ] Includes statistics and phase information
- [ ] Creates run-demo.sh for unified execution
- [ ] Supports both interactive and headless modes
- [ ] Generates stub demos for phases without clear entry points
- [ ] Follows demo script conventions from CLAUDE.md

---

## Metadata

- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: Issue 051d
- **Blocks**: None (demos are optional but valuable)
