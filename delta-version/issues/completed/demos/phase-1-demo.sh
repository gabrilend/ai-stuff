#!/bin/bash
# Phase 1 Demo: Foundation Infrastructure
# Interactive demonstration of all Phase 1 utilities:
# - Project discovery and listing
# - Repository structure validation
# - Project metadata management
# - Issue tracking overview
# - Aggregate statistics and reporting
#
# This demo showcases the foundation tools that enable management of
# the ai-stuff monorepo with 20+ projects.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
PARENT_DIR="${DIR%/*}"
SCRIPTS_DIR="${DIR}/scripts"

# -- {{{ Colors and Formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
# }}}

# -- {{{ print_header
print_header() {
    local title="$1"
    local width=70

    echo
    echo -e "${BLUE}$(printf '═%.0s' $(seq 1 $width))${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}${title}${NC}"
    echo -e "${BLUE}$(printf '═%.0s' $(seq 1 $width))${NC}"
    echo
}
# }}}

# -- {{{ print_section
print_section() {
    local title="$1"
    echo
    echo -e "${CYAN}▶ ${BOLD}${title}${NC}"
    echo -e "${DIM}$(printf '─%.0s' $(seq 1 50))${NC}"
}
# }}}

# -- {{{ print_stat
print_stat() {
    local label="$1"
    local value="$2"
    local color="${3:-$GREEN}"
    printf "  ${DIM}%-30s${NC} ${color}%s${NC}\n" "$label:" "$value"
}
# }}}

# -- {{{ press_enter
press_enter() {
    echo
    echo -e "${DIM}Press Enter to continue...${NC}"
    read -r
}
# }}}

# -- {{{ show_menu
show_menu() {
    clear
    echo
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}          ${BOLD}PHASE 1: FOUNDATION INFRASTRUCTURE DEMO${NC}               ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}          ${DIM}Delta-Version Meta-Project Showcase${NC}                    ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "  ${BOLD}1)${NC} Project Discovery        ${DIM}- list-projects.sh${NC}"
    echo -e "  ${BOLD}2)${NC} Repository Validation    ${DIM}- validate-repository.sh${NC}"
    echo -e "  ${BOLD}3)${NC} Project Metadata         ${DIM}- manage-metadata.sh${NC}"
    echo -e "  ${BOLD}4)${NC} Issue Management         ${DIM}- manage-issues.sh${NC}"
    echo -e "  ${BOLD}5)${NC} Statistics Dashboard     ${DIM}- aggregate overview${NC}"
    echo -e "  ${BOLD}6)${NC} Run All Demos            ${DIM}- sequential showcase${NC}"
    echo
    echo -e "  ${BOLD}q)${NC} Quit"
    echo
    echo -n "  Select option: "
}
# }}}

# -- {{{ demo_project_discovery
demo_project_discovery() {
    clear
    print_header "Demo 1: Project Discovery"

    echo -e "The ${BOLD}list-projects.sh${NC} utility discovers projects using heuristic scoring."
    echo -e "It identifies directories that look like software projects based on:"
    echo -e "  • Presence of ${CYAN}src/${NC}, ${CYAN}docs/${NC}, ${CYAN}issues/${NC} directories"
    echo -e "  • Vision files (${CYAN}notes/vision.md${NC})"
    echo -e "  • Build files, source code, and documentation"
    echo

    print_section "Discovered Projects (Top 10)"
    if [[ -x "${SCRIPTS_DIR}/list-projects.sh" ]]; then
        "${SCRIPTS_DIR}/list-projects.sh" 2>/dev/null | head -10 | while read -r project; do
            echo -e "    ${GREEN}●${NC} $project"
        done

        local total
        total=$("${SCRIPTS_DIR}/list-projects.sh" 2>/dev/null | wc -l)
        echo -e "    ${DIM}... and $((total - 10)) more${NC}"
    else
        echo -e "    ${RED}list-projects.sh not found${NC}"
    fi

    print_section "JSON Output Format"
    if [[ -x "${SCRIPTS_DIR}/list-projects.sh" ]]; then
        "${SCRIPTS_DIR}/list-projects.sh" --format json 2>/dev/null | head -8
        echo -e "    ${DIM}...${NC}"
    fi

    print_section "Non-Project Directories (Inverse Mode)"
    if [[ -x "${SCRIPTS_DIR}/list-projects.sh" ]]; then
        "${SCRIPTS_DIR}/list-projects.sh" --inverse 2>/dev/null | head -5 | while read -r dir; do
            echo -e "    ${YELLOW}○${NC} $dir"
        done
    fi

    press_enter
}
# }}}

# -- {{{ demo_validation
demo_validation() {
    clear
    print_header "Demo 2: Repository Validation"

    echo -e "The ${BOLD}validate-repository.sh${NC} script runs comprehensive checks on the monorepo:"
    echo -e "  • Repository root and git configuration"
    echo -e "  • Project structure validation"
    echo -e "  • Script functionality tests"
    echo -e "  • Documentation link verification"
    echo

    print_section "Quick Validation (--quick mode)"
    if [[ -x "${SCRIPTS_DIR}/validate-repository.sh" ]]; then
        # Run validation and capture output, stripping ANSI for processing
        local output
        output=$("${SCRIPTS_DIR}/validate-repository.sh" --quick 2>&1)

        # Show the formatted output
        echo "$output" | tail -20
    else
        echo -e "    ${RED}validate-repository.sh not found${NC}"
    fi

    press_enter
}
# }}}

# -- {{{ demo_metadata
demo_metadata() {
    clear
    print_header "Demo 3: Project Metadata System"

    echo -e "The ${BOLD}manage-metadata.sh${NC} utility manages project.meta.json files:"
    echo -e "  • Status tracking (active, maintenance, experimental, archived)"
    echo -e "  • Language and technology tags"
    echo -e "  • Filtering and querying projects"
    echo

    print_section "Project Statistics"
    if [[ -x "${SCRIPTS_DIR}/manage-metadata.sh" ]]; then
        "${SCRIPTS_DIR}/manage-metadata.sh" stats 2>/dev/null || echo -e "    ${DIM}(no metadata files found - run 'manage-metadata.sh init <project>')${NC}"
    else
        echo -e "    ${RED}manage-metadata.sh not found${NC}"
    fi

    print_section "Active Projects"
    if [[ -x "${SCRIPTS_DIR}/manage-metadata.sh" ]]; then
        local active
        active=$("${SCRIPTS_DIR}/manage-metadata.sh" list --status=active --format=names 2>/dev/null | head -5)
        if [[ -n "$active" ]]; then
            echo "$active" | while read -r project; do
                echo -e "    ${GREEN}●${NC} $project"
            done
        else
            echo -e "    ${DIM}No projects with status=active metadata${NC}"
        fi
    fi

    print_section "Sample Metadata (delta-version)"
    if [[ -x "${SCRIPTS_DIR}/manage-metadata.sh" ]]; then
        "${SCRIPTS_DIR}/manage-metadata.sh" show delta-version 2>/dev/null | head -15 || \
            echo -e "    ${DIM}(no metadata for delta-version)${NC}"
    fi

    press_enter
}
# }}}

# -- {{{ demo_issues
demo_issues() {
    clear
    print_header "Demo 4: Issue Management"

    echo -e "The ${BOLD}manage-issues.sh${NC} utility tracks issue files across projects:"
    echo -e "  • Lists pending, in-progress, and completed issues"
    echo -e "  • Filters by phase, status, or project"
    echo -e "  • Supports issue creation and updates"
    echo

    print_section "Delta-Version Issue Summary"
    if [[ -x "${SCRIPTS_DIR}/manage-issues.sh" ]]; then
        # Count issues by examining the directory
        local pending completed
        pending=$(find "${DIR}/issues" -maxdepth 1 -name "*.md" -type f ! -name "CLAUDE.md" ! -name "progress.md" 2>/dev/null | wc -l)
        completed=$(find "${DIR}/issues/completed" -name "*.md" -type f 2>/dev/null | wc -l)

        print_stat "Pending issues" "$pending" "$YELLOW"
        print_stat "Completed issues" "$completed" "$GREEN"
        print_stat "Total tracked" "$((pending + completed))" "$CYAN"
    else
        echo -e "    ${RED}manage-issues.sh not found${NC}"
    fi

    print_section "Recently Completed Issues"
    if [[ -d "${DIR}/issues/completed" ]]; then
        find "${DIR}/issues/completed" -name "*.md" -type f -printf "%T@ %f\n" 2>/dev/null | \
            sort -rn | head -5 | cut -d' ' -f2 | while read -r issue; do
                local title
                title=$(echo "$issue" | sed 's/\.md$//' | sed 's/-/ /g' | sed 's/^[0-9]* //')
                echo -e "    ${GREEN}✓${NC} $issue"
            done
    fi

    print_section "Issue Phases"
    echo -e "    Phase 1: Foundation Infrastructure"
    echo -e "    Phase 2: Gitignore Unification"
    echo -e "    Phase 3: History Reconstruction"
    echo -e "    Phase 4: Meta-Infrastructure"

    press_enter
}
# }}}

# -- {{{ demo_statistics
demo_statistics() {
    clear
    print_header "Demo 5: Statistics Dashboard"

    echo -e "Aggregate statistics for the ${BOLD}ai-stuff${NC} monorepo:"
    echo

    print_section "Repository Overview"

    # Project count
    local project_count
    project_count=$("${SCRIPTS_DIR}/list-projects.sh" 2>/dev/null | wc -l)
    print_stat "Total projects" "$project_count" "$CYAN"

    # Script count
    local script_count
    script_count=$(find "${SCRIPTS_DIR}" -name "*.sh" -type f 2>/dev/null | wc -l)
    print_stat "Delta-version scripts" "$script_count" "$GREEN"

    # Documentation
    local doc_count
    doc_count=$(find "${DIR}/docs" -name "*.md" -type f 2>/dev/null | wc -l)
    print_stat "Documentation files" "$doc_count" "$GREEN"

    # Issue files
    local issue_count
    issue_count=$(find "${DIR}/issues" -name "*.md" -type f 2>/dev/null | wc -l)
    print_stat "Issue files" "$issue_count" "$YELLOW"

    # Total lines of bash
    local bash_lines
    bash_lines=$(find "${SCRIPTS_DIR}" -name "*.sh" -type f -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    print_stat "Lines of bash code" "$bash_lines" "$MAGENTA"

    print_section "Delta-Version Structure"
    echo
    for subdir in docs notes src scripts libs assets issues; do
        if [[ -d "${DIR}/${subdir}" ]]; then
            local count
            count=$(find "${DIR}/${subdir}" -type f 2>/dev/null | wc -l)
            printf "    ${BLUE}%-12s${NC} %4d files\n" "${subdir}/" "$count"
        fi
    done

    print_section "Git Statistics"
    if [[ -d "${PARENT_DIR}/.git" ]]; then
        local commit_count branch_count
        commit_count=$(git -C "$PARENT_DIR" rev-list --count HEAD 2>/dev/null || echo "?")
        branch_count=$(git -C "$PARENT_DIR" branch -a 2>/dev/null | wc -l)

        print_stat "Total commits" "$commit_count" "$CYAN"
        print_stat "Branches" "$branch_count" "$GREEN"
    fi

    press_enter
}
# }}}

# -- {{{ run_all_demos
run_all_demos() {
    demo_project_discovery
    demo_validation
    demo_metadata
    demo_issues
    demo_statistics

    clear
    print_header "Phase 1 Demo Complete"

    echo -e "${GREEN}✓${NC} All Phase 1 features demonstrated successfully!"
    echo
    echo -e "${BOLD}Key Achievements:${NC}"
    echo -e "  • Repository structure established and validated"
    echo -e "  • Project discovery across 20+ projects functional"
    echo -e "  • Metadata system for project tracking in place"
    echo -e "  • Issue management foundation complete"
    echo -e "  • Statistics and reporting tools operational"
    echo
    echo -e "${BOLD}Foundation Ready For:${NC}"
    echo -e "  • Phase 2: Gitignore Unification"
    echo -e "  • Phase 3: History Reconstruction"
    echo -e "  • Phase 4: Meta-Infrastructure"
    echo

    press_enter
}
# }}}

# -- {{{ main
main() {
    # Check if running interactively
    if [[ ! -t 0 ]]; then
        # Non-interactive: run all demos sequentially
        run_all_demos
        exit 0
    fi

    # Interactive menu loop
    while true; do
        show_menu
        read -r choice

        case "$choice" in
            1) demo_project_discovery ;;
            2) demo_validation ;;
            3) demo_metadata ;;
            4) demo_issues ;;
            5) demo_statistics ;;
            6) run_all_demos ;;
            q|Q)
                clear
                echo -e "${GREEN}Thanks for exploring Phase 1!${NC}"
                echo
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}
# }}}

main "$@"
