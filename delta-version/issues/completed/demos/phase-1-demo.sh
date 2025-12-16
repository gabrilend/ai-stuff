#!/bin/bash
# Phase 1 Demo: Foundation Infrastructure
# Demonstrates the project discovery and repository structure functionality

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
PARENT_DIR="${DIR%/*}"

echo "=== Phase 1: Foundation Infrastructure ==="
echo "Goal: Establish fundamental repository infrastructure"
echo

# -- {{{ show_statistics
function show_statistics() {
    echo "Phase 1 Statistics"
    echo "=================="

    # Count completed issues
    local completed_issues
    completed_issues=$(find "${DIR}/issues" -name "*.md" -exec grep -l "✅" {} \; 2>/dev/null | wc -l)

    # Count scripts
    local script_count
    script_count=$(find "${DIR}/scripts" -name "*.sh" -type f 2>/dev/null | wc -l)

    # Count documentation files
    local doc_count
    doc_count=$(find "${DIR}/docs" -name "*.md" -type f 2>/dev/null | wc -l)

    echo "  Completed issues: $completed_issues"
    echo "  Scripts created: $script_count"
    echo "  Documentation files: $doc_count"
    echo
}
# }}}

# -- {{{ demonstrate_project_listing
function demonstrate_project_listing() {
    echo "Demonstrating: Project Listing Utility"
    echo "======================================="
    echo
    echo "The list-projects.sh script discovers and lists project directories"
    echo "using heuristic scoring based on project characteristics."
    echo

    local list_script="${DIR}/scripts/list-projects.sh"

    if [[ -f "$list_script" ]]; then
        echo "1. Project Names (default output):"
        echo "-----------------------------------"
        bash "$list_script" --names "$PARENT_DIR" | head -10
        local total
        total=$(bash "$list_script" --names "$PARENT_DIR" | wc -l)
        echo "   ... ($total total projects discovered)"
        echo

        echo "2. JSON Format Output:"
        echo "----------------------"
        bash "$list_script" --format json "$PARENT_DIR" | head -8
        echo "   ..."
        echo

        echo "3. Non-Project Directories (inverse mode):"
        echo "-------------------------------------------"
        bash "$list_script" --inverse --names "$PARENT_DIR" | head -5
        echo "   ..."
        echo
    else
        echo "ERROR: list-projects.sh not found at $list_script"
    fi
}
# }}}

# -- {{{ demonstrate_structure
function demonstrate_structure() {
    echo "Demonstrating: Repository Structure"
    echo "===================================="
    echo
    echo "Delta-Version follows a standardized project structure:"
    echo

    echo "delta-version/"
    for dir in docs notes src scripts libs assets issues; do
        if [[ -d "${DIR}/${dir}" ]]; then
            local count
            count=$(find "${DIR}/${dir}" -type f 2>/dev/null | wc -l)
            printf "├── %-12s (%d files)\n" "${dir}/" "$count"
        fi
    done
    echo
}
# }}}

# -- {{{ main
function main() {
    show_statistics
    demonstrate_structure
    demonstrate_project_listing

    echo "Phase 1 Demo Complete"
    echo "====================="
    echo "Key Achievements:"
    echo "  - Repository structure established"
    echo "  - Project discovery utility functional"
    echo "  - Foundation for subsequent phases ready"
}
# }}}

main
