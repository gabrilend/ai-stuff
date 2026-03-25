#!/bin/bash
# {{{ fix-issue-headers.sh
# Updates issue file headers to match their filenames after reorganization.
# Fixes issue numbers in headers and sub-issue tables.
# }}}

DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"
if [[ -n "$1" ]]; then
    DIR="$1"
fi

ISSUES_DIR="${DIR}/issues"
COMPLETED_DIR="${DIR}/issues/completed"

# {{{ fix_header
# Updates the first line of an issue file to use the correct issue number
fix_header() {
    local file="$1"
    local basename=$(basename "$file" .md)

    # Extract issue number from filename (e.g., "901a-rotor-data" -> "901a")
    local new_id=$(echo "$basename" | grep -oE '^[0-9]+[a-z]?')

    if [[ -z "$new_id" ]]; then
        return
    fi

    # Get the base number for parent reference (e.g., "901a" -> "901")
    local base_num=$(echo "$new_id" | grep -oE '^[0-9]+')

    # Read first line to get old ID
    local first_line=$(head -1 "$file")
    local old_id=$(echo "$first_line" | grep -oE '^# [0-9]+[a-z]?' | sed 's/^# //')

    if [[ -z "$old_id" ]]; then
        echo "SKIP: $file (no issue number in header)"
        return
    fi

    if [[ "$old_id" == "$new_id" ]]; then
        return
    fi

    echo "FIX: $file ($old_id -> $new_id)"

    # Get old base number for replacing references
    local old_base=$(echo "$old_id" | grep -oE '^[0-9]+')

    # Replace header line
    sed -i "1s/^# ${old_id}/# ${new_id}/" "$file"

    # Update parent issue reference if this is a sub-issue
    if [[ "$new_id" =~ [a-z]$ ]]; then
        sed -i "s/Parent Issue: ${old_base}/Parent Issue: ${base_num}/g" "$file"
    fi

    # Update sub-issue tables (e.g., "| 1305a |" -> "| 901a |")
    # Only if this is a parent issue (no letter suffix)
    if [[ ! "$new_id" =~ [a-z]$ ]]; then
        # Replace old sub-issue IDs in tables
        for letter in a b c d e f g h; do
            sed -i "s/| ${old_base}${letter} /| ${base_num}${letter} /g" "$file"
            sed -i "s/${old_base}${letter}/${base_num}${letter}/g" "$file"
        done
    fi

    # Update "Parent Phase" references (remove old phase numbers)
    sed -i "s/Parent Phase: Phase [0-9]*/Parent Phase: See phase progress file/g" "$file"
}
# }}}

# {{{ main
echo "Fixing issue headers in $ISSUES_DIR"

# Process open issues
for file in "${ISSUES_DIR}"/*.md; do
    if [[ -f "$file" ]]; then
        basename=$(basename "$file")
        # Skip non-issue files
        if [[ "$basename" =~ ^phase- ]] || [[ "$basename" == "REORGANIZATION-PLAN.md" ]]; then
            continue
        fi
        fix_header "$file"
    fi
done

# Process completed issues
for file in "${COMPLETED_DIR}"/*.md; do
    if [[ -f "$file" ]]; then
        fix_header "$file"
    fi
done

echo "Done."
# }}}
