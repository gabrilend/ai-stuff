#!/usr/bin/env bash
#
# test-init-project-skeleton.sh - proves init-project.sh can lay out a project
# anywhere without a sandbox, and never damages a project that already exists.
#
# In plain terms: points init-project.sh --skeleton-only at scratch folders -
# a brand-new one, one with hand-made files already in it, a copy of a real
# project - and checks that it adds exactly the standard pieces, changes nothing
# on a second run, keeps everything that was already there, refuses mixed-up
# flags, that every folder it leaves empty holds a note saying what the folder
# is for (git keeps no empty folder, so without one the folder never reaches a
# remote), and that the phase-demo picker it writes finds phase 10 as readily
# as phase 1. The RAM tiers are pointed into the scratch folder for the run, so the
# real /tmp and /dev/shm are not touched.
#
# The sandbox half (a bare project name inside a monorepo) needs bubblewrap and
# writes outside the scratch folder, so it is not exercised here beyond checking
# that it refuses cleanly when its monorepo is not a git checkout.
#
# Usage:
#   tests/test-init-project-skeleton.sh [scripts-dir]

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

INIT="${DIR}/init-project.sh"
SCRATCH="$(mktemp -d /tmp/claude-1000/test-init-skeleton.XXXXXX)"
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
mkdir -p "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}"

PASSED=0
FAILED=0

# {{{ pass / fail / check
pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
check() {
    local description="$1"
    shift
    if "$@"; then pass "${description}"; else fail "${description}"; fi
}
# }}}

# {{{ refuses
# refuses <fragment> <command...>: exits 1 and says the fragment on stderr.
refuses() {
    local fragment="$1"
    shift
    local said status
    said=$("$@" 2>&1 >/dev/null)
    status=$?
    [ "${status}" -eq 1 ] && [[ "${said}" == *"${fragment}"* ]] \
        || { printf '        (exit %s, said: %s)\n' "${status}" "${said}"; return 1; }
}
# }}}

# {{{ snapshot
# Everything about a tree that a re-run could change: paths, kinds, link
# targets, modification times and contents.
snapshot() {
    find "$1" -printf '%P %y %l %T@\n' | sort
    find "$1" -type f -exec md5sum {} + | sed "s|$1||" | sort
}
# }}}

# {{{ has_skeleton
has_skeleton() {
    local p="$1" piece
    for piece in docs notes src libs assets issues issues/completed scripts \
                 docs/HTML issues/completed/demos llm-transcripts \
                 input output desire faith strategems; do
        [ -d "${p}/${piece}" ] || { echo "        missing folder ${piece}"; return 1; }
    done
    for piece in docs/table-of-contents.md .file-index-counter \
                 issues/phase-1-progress.md .gitignore; do
        [ -f "${p}/${piece}" ] || { echo "        missing file ${piece}"; return 1; }
    done
    [ -x "${p}/run-phase-demo" ] || { echo "        run-phase-demo missing or not executable"; return 1; }
    [ -d "${p}/tmp/shared-memory" ] || { echo "        RAM tiers not reachable through tmp/"; return 1; }
}
# }}}

echo "a new project outside any monorepo"
fresh="${SCRATCH}/elsewhere/new-thing"
report=$("${INIT}" --skeleton-only "${fresh}" 2>&1)
check "--skeleton-only succeeds on a folder that does not exist yet" [ $? -eq 0 ]
check "  ...lays out every standard piece" has_skeleton "${fresh}"
check "  ...counter starts at 000" [ "$(cat "${fresh}/.file-index-counter")" = "000" ]
check "  ...gitignore holds tmp and nothing about a launcher" [ "$(cat "${fresh}/.gitignore")" = "tmp" ]
check "  ...no launcher, no CLAUDE.md sandbox notice" \
    bash -c "[ ! -e '${fresh}/scripts/enter-sandbox.sh' ] && [ ! -e '${fresh}/CLAUDE.md' ]"
check "  ...the report says the sandbox was not built, and why" \
    bash -c "grep -q 'sandbox   not built' <<< \"\$1\"" _ "${report}"
check "  ...the picker carries this project's path as its DIR" \
    grep -qx "DIR=\"${fresh}\"" "${fresh}/run-phase-demo"

# {{{ every_folder_kept
# Every folder holds at least one file somewhere beneath it, so git would keep
# them all.
every_folder_kept() {
    local p="$1" folder
    while read -r folder; do
        [ -n "$(find "${folder}" -type f -print -quit)" ] \
            || { echo "        ${folder#"${p}"/} would be lost: no file in it"; return 1; }
    done < <(find "${p}" -path "${p}/tmp" -prune -o -type d -print)
}
# }}}
check "  ...every folder holds a file, so a clone would have them all" every_folder_kept "${fresh}"
check "  ...the intent folder desire/ says what it is for" grep -q 'what you would like to be better' "${fresh}/desire/README"
check "  ...the transcripts folder's note is not a .md file the transcript tools would read" \
    bash -c "[ -f '${fresh}/llm-transcripts/README' ] && [ -z \"\$(find '${fresh}/llm-transcripts' -name '*.md')\" ]"
check "  ...a folder that already holds something (docs/) gets no note" [ ! -e "${fresh}/docs/README" ]

printf 'my own words\n' > "${fresh}/faith/README"
before=$(snapshot "${fresh}")
"${INIT}" --skeleton-only "${fresh}" >/dev/null 2>&1
check "a second run changes nothing at all" [ "${before}" = "$(snapshot "${fresh}")" ]
check "  ...an edited note is kept as it was" grep -qx 'my own words' "${fresh}/faith/README"

echo "a project that already has hand-made pieces"
kept="${SCRATCH}/kept"
mkdir -p "${kept}/docs" "${kept}/issues"
printf '058\n' > "${kept}/.file-index-counter"
printf '# hand-written contents\n' > "${kept}/docs/table-of-contents.md"
mkdir -p "${kept}/src"; printf 'print(1)\n' > "${kept}/src/001-main.lua"
printf '# phase 1, well under way\n' > "${kept}/issues/phase-1-progress.md"
printf '#!/bin/sh\necho mine\n' > "${kept}/run-phase-demo"
chmod +x "${kept}/run-phase-demo"
printf 'build/\n' > "${kept}/.gitignore"
"${INIT}" --skeleton-only "${kept}" >/dev/null 2>&1
check "the counter keeps its high-water mark" [ "$(cat "${kept}/.file-index-counter")" = "058" ]
check "the hand-written table of contents is untouched" grep -q 'hand-written' "${kept}/docs/table-of-contents.md"
check "the progress file is untouched" grep -q 'well under way' "${kept}/issues/phase-1-progress.md"
check "src/, which holds code already, gets no note" [ ! -e "${kept}/src/README" ]
check "  ...while a folder it had to make does" [ -f "${kept}/libs/README" ]
check "the project's own picker is untouched" grep -q 'echo mine' "${kept}/run-phase-demo"
check "the gitignore gained tmp and kept its own line" \
    [ "$(cat "${kept}/.gitignore")" = "$(printf 'build/\ntmp')" ]

echo "a project whose tmp link uses its own name"
custom="${SCRATCH}/custom"
mkdir -p "${custom}"
ln -s "${EXEC_TIER_ROOT}/custom-2" "${custom}/tmp"
"${INIT}" --skeleton-only "${custom}" >/dev/null 2>&1
check "the link is honoured, not re-pointed" [ "$(readlink "${custom}/tmp")" = "${EXEC_TIER_ROOT}/custom-2" ]
check "  ...and the room behind it was built" [ -d "${EXEC_TIER_ROOT}/custom-2/tmp" ]

echo "refusals"
printf 'a file\n' > "${SCRATCH}/a-file"
check "a path that is a file is refused" refuses "not a folder" "${INIT}" --skeleton-only "${SCRATCH}/a-file"
check "a project name as well as a path is refused" \
    refuses "not a project name as well" "${INIT}" --skeleton-only "${SCRATCH}/x" extra-name
check "--refresh with --skeleton-only is refused" \
    refuses "builds none" "${INIT}" --refresh --skeleton-only "${SCRATCH}/x"
check "--writable with --skeleton-only is refused" \
    refuses "builds no sandbox" "${INIT}" --writable big/ --skeleton-only "${SCRATCH}/x"
check "  ...and none of those refusals created the folder" [ ! -e "${SCRATCH}/x" ]
if command -v bwrap >/dev/null; then
    notgit="${SCRATCH}/not-a-monorepo"
    mkdir -p "${notgit}"
    check "a sandbox asked for in a folder that is not a git checkout is refused, naming --skeleton-only" \
        refuses "--skeleton-only" "${INIT}" --dir "${notgit}" some-project
    check "  ...and nothing was created there" [ ! -e "${notgit}/some-project" ]
else
    echo "  skip  sandbox refusal (bubblewrap is not installed)"
fi

echo "the phase-demo picker"
demos="${fresh}/issues/completed/demos"
check "with no demos (only the folder's note) it says so and succeeds" bash -c "'${fresh}/run-phase-demo' | grep -q 'No phase has a demo'"
for n in 1 2 10; do
    printf '#!/bin/sh\necho "phase %s ran in $1"\n' "${n}" > "${demos}/phase-${n}-demo"
    chmod +x "${demos}/phase-${n}-demo"
done
printf 'support data\n' > "${demos}/phase-2-demo-data.txt"
check "phases are listed in numeric order, 10 after 2, support files ignored" \
    bash -c "printf '\n' | '${fresh}/run-phase-demo' 2>&1 | grep -q 'Phases with a demo: 1 2 10'"
check "phase 10 runs when asked for" \
    bash -c "'${fresh}/run-phase-demo' 10 | grep -qx 'phase 10 ran in ${fresh}'"
check "a phase with no demo is refused" \
    refuses "has no demo" "${fresh}/run-phase-demo" 7

rm -rf "${SCRATCH}"
printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
