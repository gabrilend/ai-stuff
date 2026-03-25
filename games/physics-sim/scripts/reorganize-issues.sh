#!/bin/bash
# Reorganize issue files according to the 10-phase structure
# This script renames files and updates internal references

DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"
ISSUES_DIR="${DIR}/issues"
COMPLETED_DIR="${ISSUES_DIR}/completed"

# Create backup
echo "Creating backup..."
cp -r "${ISSUES_DIR}" "${DIR}/issues-backup-$(date +%Y%m%d-%H%M%S)"

# Function to rename a file and update its content
rename_issue() {
    local old_num="$1"
    local new_num="$2"
    local dir="$3"

    # Find files matching old number
    for old_file in "${dir}/${old_num}"*.md; do
        if [[ -f "$old_file" ]]; then
            # Extract the suffix (everything after the number)
            local basename=$(basename "$old_file")
            local suffix="${basename#${old_num}}"
            local new_file="${dir}/${new_num}${suffix}"

            echo "  ${old_num}${suffix} -> ${new_num}${suffix}"
            mv "$old_file" "$new_file"
        fi
    done
}

echo ""
echo "=== Phase 2: Renumbering old Phase 3 (301-306 -> 207-212) ==="
rename_issue "301" "207" "${COMPLETED_DIR}"
rename_issue "302" "208" "${COMPLETED_DIR}"
rename_issue "303" "209" "${COMPLETED_DIR}"
rename_issue "304" "210" "${COMPLETED_DIR}"
rename_issue "305" "211" "${COMPLETED_DIR}"
rename_issue "306" "212" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 3: Renumbering old Phase 4 (401-405 -> 301-305) ==="
rename_issue "401" "301" "${COMPLETED_DIR}"
rename_issue "402" "302" "${COMPLETED_DIR}"
rename_issue "403" "303" "${COMPLETED_DIR}"
rename_issue "404" "304" "${COMPLETED_DIR}"
rename_issue "405" "305" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 4: Renumbering old Phase 5 (501-507 -> 401-407) ==="
rename_issue "501" "401" "${COMPLETED_DIR}"
rename_issue "502" "402" "${COMPLETED_DIR}"
rename_issue "503" "403" "${COMPLETED_DIR}"
rename_issue "504" "404" "${COMPLETED_DIR}"
rename_issue "505" "405" "${COMPLETED_DIR}"
rename_issue "506" "406" "${COMPLETED_DIR}"
rename_issue "507" "407" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 4: Renumbering old Phase 9 (901-905 -> 408-412) ==="
rename_issue "901" "408" "${COMPLETED_DIR}"
rename_issue "902" "409" "${COMPLETED_DIR}"
rename_issue "903" "410" "${COMPLETED_DIR}"
rename_issue "904" "411" "${COMPLETED_DIR}"
rename_issue "905" "412" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 5: Renumbering old Phase 6 (601-604 -> 501-504) ==="
rename_issue "601" "501" "${COMPLETED_DIR}"
rename_issue "602" "502" "${COMPLETED_DIR}"
rename_issue "603" "503" "${COMPLETED_DIR}"
rename_issue "604" "504" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 5: Renumbering old Phase 7 (701-705 -> 505-509) ==="
rename_issue "701" "505" "${COMPLETED_DIR}"
rename_issue "702" "506" "${COMPLETED_DIR}"
rename_issue "703" "507" "${COMPLETED_DIR}"
rename_issue "704" "508" "${COMPLETED_DIR}"
rename_issue "705" "509" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 6: Renumbering old Phase 8 (801-815 -> 601-615) ==="
for i in $(seq 1 15); do
    old=$(printf "%d" $((800 + i)))
    new=$(printf "%d" $((600 + i)))
    rename_issue "$old" "$new" "${COMPLETED_DIR}"
done

echo ""
echo "=== Phase 7: Renumbering old Phase 10 (1001-1010 -> 701-710) ==="
for i in $(seq 1 10); do
    old=$(printf "%d" $((1000 + i)))
    new=$(printf "%d" $((700 + i)))
    rename_issue "$old" "$new" "${COMPLETED_DIR}"
done

echo ""
echo "=== Phase 8: Renumbering old Phase 11 (1101-1119 -> 801-819) ==="
for i in $(seq 1 19); do
    old=$(printf "%d" $((1100 + i)))
    new=$(printf "%d" $((800 + i)))
    rename_issue "$old" "$new" "${COMPLETED_DIR}"
done

echo ""
echo "=== Phase 9: Renumbering old Phase 12 (1201-1228 -> 901-928) ==="
for i in $(seq 1 28); do
    old=$(printf "%d" $((1200 + i)))
    new=$(printf "%d" $((900 + i)))
    rename_issue "$old" "$new" "${COMPLETED_DIR}"
done

echo ""
echo "=== Phase 10: Renumbering old Phase 13 (1301-1325 -> 1001-1025) ==="
# Handle completed issues
rename_issue "1302" "1002" "${COMPLETED_DIR}"
rename_issue "1303" "1003" "${COMPLETED_DIR}"
rename_issue "1304" "1004" "${COMPLETED_DIR}"
rename_issue "1308" "1008" "${COMPLETED_DIR}"
rename_issue "1309" "1009" "${COMPLETED_DIR}"
rename_issue "1310" "1010" "${COMPLETED_DIR}"

# Handle open issues (in main issues directory)
echo ""
echo "=== Renumbering open Phase 13 issues ==="
rename_issue "1301" "1001" "${ISSUES_DIR}"
rename_issue "1305" "1005" "${ISSUES_DIR}"
rename_issue "1306" "1006" "${ISSUES_DIR}"
rename_issue "1307" "1007" "${ISSUES_DIR}"
rename_issue "1311" "1011" "${ISSUES_DIR}"
rename_issue "1312" "1012" "${ISSUES_DIR}"
rename_issue "1313" "1013" "${ISSUES_DIR}"
rename_issue "1314" "1014" "${ISSUES_DIR}"
rename_issue "1315" "1015" "${ISSUES_DIR}"
rename_issue "1316" "1016" "${ISSUES_DIR}"
rename_issue "1317" "1017" "${ISSUES_DIR}"
rename_issue "1318" "1018" "${ISSUES_DIR}"
rename_issue "1319" "1019" "${ISSUES_DIR}"
rename_issue "1320" "1020" "${ISSUES_DIR}"
rename_issue "1321" "1021" "${ISSUES_DIR}"
rename_issue "1322" "1022" "${ISSUES_DIR}"
rename_issue "1323" "1023" "${ISSUES_DIR}"
rename_issue "1324" "1024" "${ISSUES_DIR}"
rename_issue "1325" "1025" "${ISSUES_DIR}"

echo ""
echo "=== Removing old phase progress files ==="
rm -f "${ISSUES_DIR}/phase-11-progress.md"
rm -f "${ISSUES_DIR}/phase-12-progress.md"
rm -f "${ISSUES_DIR}/phase-13-progress.md"

echo ""
echo "Done! Files renamed."
echo "Next steps:"
echo "  1. Update 'Parent Phase' references in all issue files"
echo "  2. Update cross-references between issues"
echo "  3. Create new phase progress files"
