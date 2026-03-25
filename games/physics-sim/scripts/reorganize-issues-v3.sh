#!/bin/bash
# Second pass reorganization - consolidate to 9 phases
# Fixes misplaced issues and merges Gameplay + Progression

DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"
ISSUES_DIR="${DIR}/issues"
COMPLETED_DIR="${ISSUES_DIR}/completed"

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

echo "=== Phase 1: Add compile time config ==="
rename_issue "1006" "112" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 2: Add physics/world issues from Editor and Dynamic ==="
# From Editor (Phase 9)
rename_issue "915" "213" "${COMPLETED_DIR}"
rename_issue "916" "214" "${COMPLETED_DIR}"
rename_issue "917" "215" "${COMPLETED_DIR}"
rename_issue "936" "216" "${COMPLETED_DIR}"
rename_issue "938" "217" "${COMPLETED_DIR}"
rename_issue "939" "218" "${COMPLETED_DIR}"
rename_issue "940" "219" "${COMPLETED_DIR}"
rename_issue "941" "220" "${COMPLETED_DIR}"
# Ball sleep system from Dynamic
rename_issue "1005" "221" "${ISSUES_DIR}"
# Trajectory history from Dynamic
rename_issue "1007" "222" "${ISSUES_DIR}"

echo ""
echo "=== Phase 3: Add visual feedback issues ==="
rename_issue "1001" "319" "${ISSUES_DIR}"
rename_issue "1002" "320" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 4: Add reticle issues ==="
rename_issue "801" "410" "${COMPLETED_DIR}"
rename_issue "918" "411" "${COMPLETED_DIR}"
rename_issue "919" "412" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 5: Merge in Progression (old Phase 6) ==="
rename_issue "601" "508" "${COMPLETED_DIR}"
rename_issue "602" "509" "${COMPLETED_DIR}"
rename_issue "603" "510" "${COMPLETED_DIR}"
rename_issue "604" "511" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 6: Renumber Competition (old Phase 7) + add portal ==="
rename_issue "701" "601" "${COMPLETED_DIR}"
rename_issue "702" "602" "${COMPLETED_DIR}"
rename_issue "703" "603" "${COMPLETED_DIR}"
rename_issue "704" "604" "${COMPLETED_DIR}"
rename_issue "705" "605" "${COMPLETED_DIR}"
rename_issue "706" "606" "${COMPLETED_DIR}"
rename_issue "707" "607" "${COMPLETED_DIR}"
rename_issue "708" "608" "${COMPLETED_DIR}"
rename_issue "709" "609" "${ISSUES_DIR}"
rename_issue "710" "610" "${ISSUES_DIR}"
rename_issue "942" "611" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 7: Renumber Stages (old Phase 8 minus 801) ==="
rename_issue "802" "701" "${COMPLETED_DIR}"
rename_issue "803" "702" "${COMPLETED_DIR}"
rename_issue "804" "703" "${COMPLETED_DIR}"
rename_issue "805" "704" "${COMPLETED_DIR}"
rename_issue "806" "705" "${COMPLETED_DIR}"
rename_issue "807" "706" "${COMPLETED_DIR}"
rename_issue "808" "707" "${COMPLETED_DIR}"
rename_issue "809" "708" "${COMPLETED_DIR}"
rename_issue "810" "709" "${COMPLETED_DIR}"
rename_issue "811" "710" "${COMPLETED_DIR}"
rename_issue "812" "711" "${COMPLETED_DIR}"

echo ""
echo "=== Phase 8: Renumber Editor (old Phase 9 minus moved issues) ==="
# Core editor issues 901-914 -> 801-814
rename_issue "901" "801" "${COMPLETED_DIR}"
rename_issue "902" "802" "${COMPLETED_DIR}"
rename_issue "903" "803" "${COMPLETED_DIR}"
rename_issue "904" "804" "${COMPLETED_DIR}"
rename_issue "905" "805" "${COMPLETED_DIR}"
rename_issue "906" "806" "${COMPLETED_DIR}"
rename_issue "907" "807" "${COMPLETED_DIR}"
rename_issue "908" "808" "${COMPLETED_DIR}"
rename_issue "909" "809" "${COMPLETED_DIR}"
rename_issue "910" "810" "${COMPLETED_DIR}"
rename_issue "911" "811" "${COMPLETED_DIR}"
rename_issue "912" "812" "${COMPLETED_DIR}"
rename_issue "913" "813" "${COMPLETED_DIR}"
rename_issue "914" "814" "${COMPLETED_DIR}"
# Standalone editor 920-935 -> 815-830
rename_issue "920" "815" "${COMPLETED_DIR}"
rename_issue "921" "816" "${COMPLETED_DIR}"
rename_issue "922" "817" "${COMPLETED_DIR}"
rename_issue "923" "818" "${COMPLETED_DIR}"
rename_issue "924" "819" "${COMPLETED_DIR}"
rename_issue "925" "820" "${COMPLETED_DIR}"
rename_issue "926" "821" "${COMPLETED_DIR}"
rename_issue "927" "822" "${COMPLETED_DIR}"
rename_issue "928" "823" "${COMPLETED_DIR}"
rename_issue "929" "824" "${COMPLETED_DIR}"
rename_issue "930" "825" "${COMPLETED_DIR}"
rename_issue "931" "826" "${COMPLETED_DIR}"
rename_issue "932" "827" "${COMPLETED_DIR}"
rename_issue "933" "828" "${COMPLETED_DIR}"
rename_issue "934" "829" "${COMPLETED_DIR}"
rename_issue "935" "830" "${COMPLETED_DIR}"
# File picker 937 -> 831
rename_issue "937" "831" "${COMPLETED_DIR}"
# UI polish 943-947 -> 832-836
rename_issue "943" "832" "${COMPLETED_DIR}"
rename_issue "944" "833" "${COMPLETED_DIR}"
rename_issue "945" "834" "${COMPLETED_DIR}"
rename_issue "946" "835" "${COMPLETED_DIR}"
rename_issue "947" "836" "${COMPLETED_DIR}"
# Add issues from Dynamic
rename_issue "1008" "837" "${ISSUES_DIR}"
rename_issue "1009" "838" "${ISSUES_DIR}"
rename_issue "1010" "839" "${ISSUES_DIR}"

echo ""
echo "=== Phase 9: Renumber Dynamic Systems (old Phase 10 remaining) ==="
rename_issue "1003" "901" "${ISSUES_DIR}"
rename_issue "1004" "902" "${ISSUES_DIR}"
rename_issue "1011" "903" "${ISSUES_DIR}"

echo ""
echo "=== Remove old phase-10-progress.md ==="
rm -f "${ISSUES_DIR}/phase-10-progress.md"

echo ""
echo "Done! Second pass reorganization complete."
