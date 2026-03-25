#!/bin/bash
# Reorganize issue files according to the v2 10-phase structure
# This script renames files according to REORGANIZATION-PLAN.md v2

DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"
ISSUES_DIR="${DIR}/issues"
COMPLETED_DIR="${ISSUES_DIR}/completed"

# Function to rename a file
rename_issue() {
    local old_num="$1"
    local new_num="$2"
    local dir="$3"

    for old_file in "${dir}/${old_num}"*.md; do
        if [[ -f "$old_file" ]]; then
            local basename=$(basename "$old_file")
            local suffix="${basename#${old_num}}"
            local new_file="${dir}/${new_num}${suffix}"
            echo "  ${old_num}${suffix} -> ${new_num}${suffix}"
            mv "$old_file" "$new_file"
        fi
    done
}

echo "=== Phase 1: Adding parallel processing (401-405 -> 107-111) ==="
rename_issue "401" "107" "${COMPLETED_DIR}"
rename_issue "402" "108" "${COMPLETED_DIR}"
rename_issue "403" "109" "${COMPLETED_DIR}"
rename_issue "404" "110" "${COMPLETED_DIR}"
rename_issue "405" "111" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 2: Adding ball physics (301-306 -> 207-212) ==="
rename_issue "301" "207" "${COMPLETED_DIR}"
rename_issue "302" "208" "${COMPLETED_DIR}"
rename_issue "303" "209" "${COMPLETED_DIR}"
rename_issue "304" "210" "${COMPLETED_DIR}"
rename_issue "305" "211" "${COMPLETED_DIR}"
rename_issue "306" "212" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 3: Feedback Systems ==="
# 501-507 -> 301-307
rename_issue "501" "301" "${COMPLETED_DIR}"
rename_issue "502" "302" "${COMPLETED_DIR}"
rename_issue "503" "303" "${COMPLETED_DIR}"
rename_issue "504" "304" "${COMPLETED_DIR}"
rename_issue "505" "305" "${COMPLETED_DIR}"
rename_issue "506" "306" "${COMPLETED_DIR}"
rename_issue "507" "307" "${COMPLETED_DIR}"
# 901-905 -> 308-312
rename_issue "901" "308" "${COMPLETED_DIR}"
rename_issue "902" "309" "${COMPLETED_DIR}"
rename_issue "903" "310" "${COMPLETED_DIR}"
rename_issue "904" "311" "${COMPLETED_DIR}"
rename_issue "905" "312" "${COMPLETED_DIR}"
# Particle effects from old phase 8
rename_issue "812" "313" "${COMPLETED_DIR}"
rename_issue "813" "314" "${COMPLETED_DIR}"
rename_issue "815" "315" "${COMPLETED_DIR}"
# Scoring issues from old phase 13
rename_issue "1321" "316" "${ISSUES_DIR}"
rename_issue "1323" "317" "${ISSUES_DIR}"
rename_issue "1324" "318" "${ISSUES_DIR}"

echo ""
echo "=== Phase 4: Display ==="
# 601-604 -> 401-404
rename_issue "601" "401" "${COMPLETED_DIR}"
rename_issue "602" "402" "${COMPLETED_DIR}"
rename_issue "603" "403" "${COMPLETED_DIR}"
rename_issue "604" "404" "${COMPLETED_DIR}"
# Escape key from old phase 8
rename_issue "811" "405" "${COMPLETED_DIR}"
# UI issues from old phase 13
rename_issue "1314" "406" "${ISSUES_DIR}"
rename_issue "1315" "407" "${ISSUES_DIR}"
rename_issue "1316" "408" "${ISSUES_DIR}"
rename_issue "1317" "409" "${ISSUES_DIR}"

echo ""
echo "=== Phase 5: Gameplay ==="
# 701-705 -> 501-505
rename_issue "701" "501" "${COMPLETED_DIR}"
rename_issue "702" "502" "${COMPLETED_DIR}"
rename_issue "703" "503" "${COMPLETED_DIR}"
rename_issue "704" "504" "${COMPLETED_DIR}"
rename_issue "705" "505" "${COMPLETED_DIR}"
# Spawner issues from old phase 13
rename_issue "1309" "506" "${COMPLETED_DIR}"
rename_issue "1325" "507" "${ISSUES_DIR}"

echo ""
echo "=== Phase 6: Progression (upgrade issues from old phase 8) ==="
rename_issue "801" "601" "${COMPLETED_DIR}"
rename_issue "802" "602" "${COMPLETED_DIR}"
rename_issue "803" "603" "${COMPLETED_DIR}"
rename_issue "810" "604" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 7: Competition (adversary/combat from old phase 8 + 13) ==="
rename_issue "804" "701" "${COMPLETED_DIR}"
rename_issue "805" "702" "${COMPLETED_DIR}"
rename_issue "806" "703" "${COMPLETED_DIR}"
rename_issue "807" "704" "${COMPLETED_DIR}"
rename_issue "808" "705" "${COMPLETED_DIR}"
rename_issue "809" "706" "${COMPLETED_DIR}"
rename_issue "814" "707" "${COMPLETED_DIR}"
rename_issue "1302" "708" "${COMPLETED_DIR}"
rename_issue "1318" "709" "${ISSUES_DIR}"
rename_issue "1320" "710" "${ISSUES_DIR}"

echo ""
echo "=== Phase 8: Stages (old phase 10 + stage issues from 13) ==="
rename_issue "1001" "801" "${COMPLETED_DIR}"
rename_issue "1002" "802" "${COMPLETED_DIR}"
rename_issue "1003" "803" "${COMPLETED_DIR}"
rename_issue "1004" "804" "${COMPLETED_DIR}"
rename_issue "1005" "805" "${COMPLETED_DIR}"
rename_issue "1006" "806" "${COMPLETED_DIR}"
rename_issue "1007" "807" "${COMPLETED_DIR}"
rename_issue "1008" "808" "${COMPLETED_DIR}"
rename_issue "1009" "809" "${COMPLETED_DIR}"
rename_issue "1010" "810" "${COMPLETED_DIR}"
rename_issue "1304" "811" "${COMPLETED_DIR}"
rename_issue "1308" "812" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 9: Editor (old phases 11 + 12) ==="
# 1101-1119 -> 901-919
for i in $(seq 1 19); do
    old=$((1100 + i))
    new=$((900 + i))
    rename_issue "$old" "$new" "${COMPLETED_DIR}"
done
# 1201-1228 -> 920-947
for i in $(seq 1 28); do
    old=$((1200 + i))
    new=$((919 + i))
    rename_issue "$old" "$new" "${COMPLETED_DIR}"
done

echo ""
echo "=== Phase 10: Dynamic & Advanced ==="
rename_issue "1301" "1001" "${ISSUES_DIR}"
rename_issue "1303" "1002" "${COMPLETED_DIR}"
rename_issue "1305" "1003" "${ISSUES_DIR}"
rename_issue "1306" "1004" "${ISSUES_DIR}"
rename_issue "1307" "1005" "${ISSUES_DIR}"
rename_issue "1310" "1006" "${COMPLETED_DIR}"
rename_issue "1311" "1007" "${ISSUES_DIR}"
rename_issue "1312" "1008" "${ISSUES_DIR}"
rename_issue "1313" "1009" "${ISSUES_DIR}"
rename_issue "1319" "1010" "${ISSUES_DIR}"
rename_issue "1322" "1011" "${ISSUES_DIR}"

echo ""
echo "=== Removing old phase progress files ==="
rm -f "${ISSUES_DIR}/phase-11-progress.md"
rm -f "${ISSUES_DIR}/phase-12-progress.md"
rm -f "${ISSUES_DIR}/phase-13-progress.md"

echo ""
echo "Done! Files renamed according to v2 reorganization plan."
