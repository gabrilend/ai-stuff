#!/usr/bin/env bash
#
# test-allow-own-ram-tiers.sh - proves the RAM-tier hook lets a session into
# its own project's scratch space and nowhere else.
#
# In plain terms: builds pretend projects in a scratch folder, with pretend
# /tmp and /dev/shm roots beside them, then asks the hook about one path at a
# time, as Claude Code would before a file tool runs, and checks whether it
# answered "allow" or stayed quiet. Nothing outside the scratch folder is
# touched or trusted: the hook's two RAM roots are pointed into it for the run.
#
# Usage:
#   tests/test-allow-own-ram-tiers.sh [scripts-dir]
#
# Exits 0 when every case passes, 1 otherwise, naming each failure.

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

HOOK="${DIR}/harness-hooks/allow-own-ram-tiers"

SCRATCH="$(mktemp -d /tmp/claude-1000/test-allow-own-ram-tiers.XXXXXX)"
trap 'rm -rf "${SCRATCH}"' EXIT
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
PROJECTS="${SCRATCH}/projects"
DISK="${SCRATCH}/disk"
mkdir -p "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}" "${PROJECTS}" "${DISK}"

PASSED=0
FAILED=0

# {{{ build_project
# A project folder with whole tiers, the way libs/ensure-ram-tiers lays them.
build_project() {
    local name="$1"
    mkdir -p "${PROJECTS}/${name}/src/deep" "${EXEC_TIER_ROOT}/${name}/tmp" "${ARTIFACT_TIER_ROOT}/${name}"
    ln -s "${EXEC_TIER_ROOT}/${name}" "${PROJECTS}/${name}/tmp"
    ln -s "${ARTIFACT_TIER_ROOT}/${name}" "${EXEC_TIER_ROOT}/${name}/shared-memory"
    printf 'log line\n' > "${ARTIFACT_TIER_ROOT}/${name}/run.log"
}
# }}}

# {{{ answer_of
# Asks the hook about one tool call and prints "allow", "quiet", or "warned"
# (no decision, but a message to the person).
answer_of() {
    local cwd="$1" tool="$2" field="$3" path="$4"
    local input out
    input="$(jq -n --arg cwd "${cwd}" --arg tool "${tool}" --arg field "${field}" --arg path "${path}" \
        '{tool_name: $tool, tool_input: {($field): $path}, cwd: $cwd}')"
    out="$("${HOOK}" "" "${DIR}" <<< "${input}" 2>/dev/null)"
    if [ -z "${out}" ]; then printf 'quiet'; return; fi
    if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${out}")" = "allow" ]; then
        printf 'allow'
    elif [ -n "$(jq -r '.systemMessage // empty' <<< "${out}")" ]; then
        printf 'warned'
    else
        printf 'other: %s' "${out}"
    fi
}
# }}}

# {{{ expect
expect() {
    local want="$1" label="$2"
    shift 2
    local got
    got="$(answer_of "$@")"
    if [ "${got}" = "${want}" ]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL: %s (wanted %s, got %s)\n' "${label}" "${want}" "${got}"
    fi
}
# }}}

build_project alpha
build_project beta
A="${PROJECTS}/alpha"

# inside the rooms, by every name
expect allow "the artifact room through the project's link"      "${A}" Read file_path "${A}/tmp/shared-memory/run.log"
expect allow "the artifact room by its own name"                 "${A}" Read file_path "${ARTIFACT_TIER_ROOT}/alpha/run.log"
expect allow "the exec room by its own name"                     "${A}" Write file_path "${EXEC_TIER_ROOT}/alpha/tmp/build.lua"
expect allow "a file not written yet, in a folder not made yet"  "${A}" Write file_path "${A}/tmp/shared-memory/new/deeper/out.txt"
expect allow "the room itself"                                   "${A}" Glob path "${A}/tmp/shared-memory"
expect allow "a relative path, read from the session's folder"   "${A}" Edit file_path "tmp/shared-memory/run.log"
expect quiet "a session in a subfolder gets no exception"       "${A}/src/deep" Read file_path "${A}/tmp/shared-memory/run.log"
expect quiet "nor does a session in the folder above projects"  "${PROJECTS}" Read file_path "${A}/tmp/shared-memory/run.log"
expect allow "a cwd written with a trailing slash"              "${A}/" Read file_path "${A}/tmp/shared-memory/run.log"
expect quiet "a session at the filesystem root"                 "/" Read file_path "/tmp/x"
ln -s "${ARTIFACT_TIER_ROOT}/alpha" "${DISK}/side-door"
expect allow "another link that leads into the room"             "${A}" Read file_path "${DISK}/side-door/run.log"

# each tool's own path field
expect allow "Edit"         "${A}" Edit file_path "${A}/tmp/shared-memory/run.log"
expect allow "MultiEdit"    "${A}" MultiEdit file_path "${A}/tmp/shared-memory/run.log"
expect allow "NotebookEdit" "${A}" NotebookEdit notebook_path "${A}/tmp/shared-memory/n.ipynb"
expect allow "Grep"         "${A}" Grep path "${A}/tmp/shared-memory"
expect quiet "a tool this hook does not judge"  "${A}" Bash command "cat ${A}/tmp/shared-memory/run.log"
expect quiet "Glob with no path"                "${A}" Glob pattern "*.log"

# outside the rooms: no answer, Claude Code decides
expect quiet "another project's rooms"                   "${A}" Read file_path "${ARTIFACT_TIER_ROOT}/beta/run.log"
mkdir -p "${ARTIFACT_TIER_ROOT}/alpha-other"
expect quiet "a sibling whose name starts the same"      "${A}" Read file_path "${ARTIFACT_TIER_ROOT}/alpha-other/x"
expect quiet "the RAM root itself"                       "${A}" Glob path "${ARTIFACT_TIER_ROOT}"
expect quiet "climbing out of a room with .."            "${A}" Read file_path "${A}/tmp/shared-memory/../../beta/x"
expect quiet "the project's own source"                  "${A}" Read file_path "${A}/src/x.lua"
expect quiet "somewhere else entirely"                   "${A}" Write file_path "/etc/hosts"

# projects without whole, trustworthy rooms get no exception
mkdir -p "${PROJECTS}/no-link"
expect quiet "a project with no tmp link"                "${PROJECTS}/no-link" Read file_path "${ARTIFACT_TIER_ROOT}/alpha/run.log"
mkdir -p "${PROJECTS}/to-disk" "${DISK}/to-disk"
ln -s "${DISK}/to-disk" "${PROJECTS}/to-disk/tmp"
expect quiet "a tmp link into a disk folder"             "${PROJECTS}/to-disk" Write file_path "${PROJECTS}/to-disk/tmp/x"
mkdir -p "${PROJECTS}/to-root"
ln -s "${EXEC_TIER_ROOT}" "${PROJECTS}/to-root/tmp"
expect quiet "a tmp link at the RAM root itself"         "${PROJECTS}/to-root" Read file_path "${EXEC_TIER_ROOT}/alpha/x"
mkdir -p "${PROJECTS}/shm-out" "${EXEC_TIER_ROOT}/shm-out"
ln -s "${EXEC_TIER_ROOT}/shm-out" "${PROJECTS}/shm-out/tmp"
ln -s "${DISK}" "${EXEC_TIER_ROOT}/shm-out/shared-memory"
expect quiet "a shared-memory link out of the RAM root"  "${PROJECTS}/shm-out" Write file_path "${DISK}/x"
expect allow "while that project's exec room still counts" "${PROJECTS}/shm-out" Write file_path "${EXEC_TIER_ROOT}/shm-out/x"
mkdir -p "${PROJECTS}/dangling"
ln -s "${EXEC_TIER_ROOT}/gone-after-reboot" "${PROJECTS}/dangling/tmp"
expect quiet "a tmp link leading nowhere"                "${PROJECTS}/dangling" Write file_path "${PROJECTS}/dangling/tmp/x"

# input it cannot read is announced, never silently judged
expect warned "a cwd that is not absolute"               "relative/place" Read file_path "${A}/tmp/shared-memory/run.log"
out="$(printf 'not json' | "${HOOK}" "" "${DIR}" 2>/dev/null)"
if [ -n "$(jq -r '.systemMessage // empty' <<< "${out}")" ] && [ -z "$(jq -r '.hookSpecificOutput // empty' <<< "${out}")" ]; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
    printf 'FAIL: unreadable input is announced and gets no answer (got %s)\n' "${out}"
fi

printf '%s passed, %s failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
