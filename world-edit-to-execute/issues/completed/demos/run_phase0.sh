#!/bin/bash
# Phase 0 Demo - Tooling/Infrastructure
# Launches issue-splitter.sh in interactive TUI mode to demonstrate
# all Phase 0 features: checkbox selection, streaming, auto-implement, etc.

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# {{{ print_banner
print_banner() {
    echo ""
    echo "========================================"
    echo "  Phase 0: Tooling/Infrastructure"
    echo "========================================"
    echo ""
    echo "This demo launches the issue-splitter tool in interactive mode."
    echo ""
    echo "Completed Features (18/18 issues):"
    echo "  - Issue splitter with automated analysis"
    echo "  - Streaming queue for parallel processing"
    echo "  - Execute mode for auto-generating sub-issues"
    echo "  - Checkbox-style TUI with vim keybindings"
    echo "  - Shared TUI library for cross-project reuse"
    echo "  - Auto-implement via Claude CLI"
    echo ""
    echo "Controls:"
    echo "  j/k or arrows  - Navigate"
    echo "  i/space        - Select/toggle"
    echo "  Enter          - Confirm"
    echo "  q              - Quit"
    echo ""
}
# }}}

# {{{ main
main() {
    print_banner

    echo "Press Enter to launch interactive mode..."
    read -r

    "${DIR}/src/cli/issue-splitter.sh" -I

    echo ""
    echo "========================================"
    echo "  Phase 0 Demo Complete"
    echo "========================================"
}
# }}}

main "$@"
