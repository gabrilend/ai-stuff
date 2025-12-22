#!/bin/bash
# Test script for get_analysis_verdict function
# Tests the verdict extraction logic added in uncommitted changes
#
# This function parses analysis sections to determine if they recommend
# splitting an issue into sub-issues.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/world-edit-to-execute}"

# {{{ get_analysis_verdict
# Extracted from issue-splitter.sh for isolated testing
get_analysis_verdict() {
    local file="$1"
    local analysis=""
    analysis=$(awk '
        /^## Sub-Issue Analysis$/ || /^## Initial Analysis$/ {
            capturing = 1
            next
        }
        capturing {
            if (/^---$/ || /^## (Implementation Notes|Related Documents|Generated Sub-Issues|Structure Review|Acceptance Criteria|Notes)/) {
                capturing = 0
            } else {
                print $0
            }
        }
    ' "$file" 2>/dev/null)

    [[ -z "$analysis" ]] && echo "unknown" && return

    # Check for "don't split" indicators first (more specific)
    if echo "$analysis" | grep -qiE "(don't|do not|does not) (recommend )?split|keep as (single|one) issue|does not (need|benefit)|not (be )?split|Recommendation:.*Keep|Recommendation:.*Do Not Split|No splitting needed"; then
        echo "no-split"
        return
    fi

    # Check for "split" indicators
    if echo "$analysis" | grep -qiE "would benefit from split|Split into [0-9]+ sub-issues|Recommendation:.*Split|SPLIT|should be split|recommend split|split this issue"; then
        echo "split"
        return
    fi

    echo "unknown"
}
# }}}

# {{{ main
main() {
    echo "Testing get_analysis_verdict() function"
    echo "========================================"
    echo ""
    echo "This tests the verdict extraction on Phase 3 & 4 issues."
    echo "Expected: All analyzed issues should return 'split' or 'no-split'"
    echo ""

    cd "$DIR"

    local pass=0
    local fail=0
    local total=0

    echo "Phase 3 Issues (301-309):"
    echo "-------------------------"
    for f in issues/30*.md; do
        [[ -f "$f" ]] || continue
        ((total++))
        verdict=$(get_analysis_verdict "$f")
        if [[ "$verdict" == "unknown" ]]; then
            printf "  FAIL: %-40s -> %s\n" "$(basename "$f")" "$verdict"
            ((fail++))
        else
            printf "  PASS: %-40s -> %s\n" "$(basename "$f")" "$verdict"
            ((pass++))
        fi
    done

    echo ""
    echo "Phase 4 Issues (401-408):"
    echo "-------------------------"
    for f in issues/40*.md; do
        [[ -f "$f" ]] || continue
        ((total++))
        verdict=$(get_analysis_verdict "$f")
        if [[ "$verdict" == "unknown" ]]; then
            printf "  FAIL: %-40s -> %s\n" "$(basename "$f")" "$verdict"
            ((fail++))
        else
            printf "  PASS: %-40s -> %s\n" "$(basename "$f")" "$verdict"
            ((pass++))
        fi
    done

    echo ""
    echo "========================================"
    echo "Results: $pass/$total passed ($fail failures)"

    if [[ $fail -eq 0 ]]; then
        echo "All tests PASSED"
        return 0
    else
        echo "Some tests FAILED"
        return 1
    fi
}
# }}}

main "$@"
