#!/bin/bash
# test-issue-splitter.sh
# Debug script for testing issue-splitter's file detection logic.
# Tests pattern matching and text file detection for issue files.
#
# Usage:
#   ./test-issue-splitter.sh [issues_dir]
#   ./test-issue-splitter.sh /path/to/project/issues

set -euo pipefail

# {{{ Configuration
DIR="${1:-/mnt/mtwo/programming/ai-stuff/world-edit-to-execute}"
ISSUES_DIR="${DIR}/issues"
PATTERN="[0-9]*.md"
# }}}

# {{{ is_text_file
is_text_file() {
    # Check if first ~100 bytes are ASCII (printable + whitespace)
    # Returns 0 if text, 1 if binary
    local file="$1"
    local sample
    sample=$(head -c 100 "$file" 2>/dev/null | tr -d '[:print:][:space:]')
    [[ -z "$sample" ]]
}
# }}}

# {{{ main
main() {
    echo "=== Issue Splitter Debug Test ==="
    echo ""
    echo "Directory: $DIR"
    echo "Issues dir: $ISSUES_DIR"
    echo "Pattern: $PATTERN"
    echo "Base pattern: ${PATTERN%.md}"
    echo ""

    if [[ ! -d "$ISSUES_DIR" ]]; then
        echo "ERROR: Issues directory not found: $ISSUES_DIR"
        exit 1
    fi

    echo "=== Files matching ${PATTERN} (with .md) ==="
    local md_count
    md_count=$(find "$ISSUES_DIR" -maxdepth 1 -name "$PATTERN" -type f 2>/dev/null | wc -l)
    find "$ISSUES_DIR" -maxdepth 1 -name "$PATTERN" -type f 2>/dev/null | head -5 | while read -r f; do
        echo "  $(basename "$f")"
    done
    echo "(total: $md_count)"
    echo ""

    echo "=== Files matching ${PATTERN%.md} (without .md) ==="
    local base_pattern="${PATTERN%.md}"
    local all_count
    all_count=$(find "$ISSUES_DIR" -maxdepth 1 -name "$base_pattern" -type f 2>/dev/null | wc -l)
    find "$ISSUES_DIR" -maxdepth 1 -name "$base_pattern" -type f 2>/dev/null | head -10 | while read -r f; do
        local base
        base=$(basename "$f")
        # Check if it has an extension
        if [[ "$base" == *.* ]]; then
            echo "  $base (has extension, skip)"
        else
            echo "  $base (no extension)"
        fi
    done
    echo "(total: $all_count)"
    echo ""

    echo "=== Text file detection (first 5 extension-less files) ==="
    find "$ISSUES_DIR" -maxdepth 1 -name "$base_pattern" -type f 2>/dev/null | head -5 | while read -r f; do
        local base
        base=$(basename "$f")
        if [[ "$base" != *.* ]]; then
            if is_text_file "$f"; then
                echo "  TEXT:   $base"
                echo "          First 60 chars: $(head -c 60 "$f" | tr '\n' ' ')..."
            else
                echo "  BINARY: $base"
            fi
        fi
    done
    echo ""

    echo "=== Summary ==="
    local extensionless_text=0
    while IFS= read -r f; do
        local base
        base=$(basename "$f")
        if [[ "$base" != *.* ]] && is_text_file "$f"; then
            ((++extensionless_text))
        fi
    done < <(find "$ISSUES_DIR" -maxdepth 1 -name "$base_pattern" -type f 2>/dev/null)

    echo "Files with .md extension: $md_count"
    echo "Extension-less text files: $extensionless_text"
    echo "Total potential issues: $((md_count + extensionless_text))"
}
# }}}

main "$@"
