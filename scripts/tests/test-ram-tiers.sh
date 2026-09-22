#!/usr/bin/env bash
#
# test-ram-tiers.sh - proves the RAM scratch tiers rebuild themselves correctly.
#
# In plain terms: builds a handful of pretend projects in a scratch folder, breaks
# their scratch space in every way a reboot or a slip of the hand can, and checks
# that the shared library (libs/ensure-ram-tiers), its Lua wrapper, and the
# session-start hook (restore-ram-tiers) each either repair it exactly or refuse
# with a message - never half-repair, never guess. Nothing outside the scratch
# folder is touched: the library's two RAM roots are pointed into it for the run.
#
# Usage:
#   tests/test-ram-tiers.sh [scripts-dir]
#
# Exits 0 when every case passes, 1 otherwise, naming each failure.

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

LIBRARY="${DIR}/libs/ensure-ram-tiers"
LUA_LIBRARY="${DIR}/libs/ensure-ram-tiers.lua"
HOOK="${DIR}/restore-ram-tiers"

# The scratch world. The two roots stand in for /tmp and /dev/shm; DISK stands in
# for "somewhere that is not RAM", which the library must refuse to build into.
SCRATCH="$(mktemp -d /tmp/claude-1000/test-ram-tiers.XXXXXX)"
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
PROJECTS="${SCRATCH}/projects"
DISK="${SCRATCH}/disk"
mkdir -p "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}" "${PROJECTS}" "${DISK}"

PASSED=0
FAILED=0

# {{{ pass / fail
pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
# }}}

# {{{ check
# check <description> <command...>: passes when the command succeeds.
check() {
    local description="$1"
    shift
    if "$@"; then pass "${description}"; else fail "${description}"; fi
}
# }}}

# {{{ new_project
# Makes an empty pretend project and prints its path.
new_project() {
    local path="${PROJECTS}/$1"
    mkdir -p "${path}/src"
    printf '%s\n' "${path}"
}
# }}}

# {{{ tiers_whole
# Is this project's door, exec tier, exec/tmp, inner door and artifact tier all
# present and pointing where they should?
tiers_whole() {
    local project="$1" exec_name="$2" artifact_name="$3"
    [ -L "${project}/tmp" ] \
        && [ "$(readlink "${project}/tmp")" = "${EXEC_TIER_ROOT}/${exec_name}" ] \
        && [ -d "${EXEC_TIER_ROOT}/${exec_name}/tmp" ] \
        && [ -L "${EXEC_TIER_ROOT}/${exec_name}/shared-memory" ] \
        && [ "$(readlink "${EXEC_TIER_ROOT}/${exec_name}/shared-memory")" = "${ARTIFACT_TIER_ROOT}/${artifact_name}" ] \
        && [ -d "${ARTIFACT_TIER_ROOT}/${artifact_name}" ] \
        && [ -d "${project}/tmp/shared-memory" ]
}
# }}}

# {{{ reboot
# What a reboot does: empties both RAM roots, leaves projects on disk alone.
reboot() {
    rm -rf "${EXEC_TIER_ROOT:?}"/* "${ARTIFACT_TIER_ROOT:?}"/*
}
# }}}

# {{{ refuses
# refuses <expected-message-fragment> <command...>: passes when the command exits
# 1 and says something containing the fragment on stderr.
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

# {{{ hook_with
# Runs the hook with a JSON body built from a cwd, capturing stdout separately.
HOOK_STDOUT=""
hook_with() {
    local cwd="$1"
    local body
    body=$(jq -nc --arg cwd "${cwd}" '{session_id:"t",hook_event_name:"SessionStart",source:"startup",cwd:$cwd}')
    HOOK_STDOUT=$(printf '%s' "${body}" | "${HOOK}" "${DIR}")
}
# }}}

echo "ensure mode"
p=$(new_project alpha)
check "a fresh project gets door and both rooms" bash "${LIBRARY}" "${p}"
check "  ...laid out exactly" tiers_whole "${p}" alpha alpha
before=$(ls -lR "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}" "${p}")
check "ensuring twice succeeds" bash "${LIBRARY}" --ensure "${p}"
check "  ...and changes nothing" [ "${before}" = "$(ls -lR "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}" "${p}")" ]
check "a relative project path (with trailing slash) names the same tiers" \
    env --chdir="${PROJECTS}" bash "${LIBRARY}" alpha/
check "  ...and made no second tier (such as one called '.' or 'alpha/')" \
    [ "$(ls -A "${EXEC_TIER_ROOT}")" = "alpha" ]

echo "restore mode"
reboot
check "after a reboot, alpha's door dangles" [ ! -e "${p}/tmp" ]
check "restore rebuilds behind the dangling door" bash "${LIBRARY}" --restore "${p}"
check "  ...laid out exactly" tiers_whole "${p}" alpha alpha

q=$(new_project bravo)
ln -s "${EXEC_TIER_ROOT}/bravo-custom" "${q}/tmp"
check "a door to a custom-named tier is honoured" bash "${LIBRARY}" --restore "${q}"
check "  ...the exec tier keeps its custom name; the artifact tier takes the folder name" \
    tiers_whole "${q}" bravo-custom bravo

r=$(new_project charlie)
ln -s "../../exec/charlie-rel" "${r}/tmp"
check "a relative door is resolved against the project folder" bash "${LIBRARY}" --restore "${r}"
check "  ...and the room is where the door leads" [ -d "${EXEC_TIER_ROOT}/charlie-rel/tmp" ]

s=$(new_project delta)
check "restore refuses to create a door that is not there" \
    refuses "never creates one" bash "${LIBRARY}" --restore "${s}"
check "  ...and created none" [ ! -e "${s}/tmp" ]

echo "refusals"
t=$(new_project echo-real-folder)
mkdir "${t}/tmp"
check "a real tmp folder (the sandbox case) is left alone by ensure" bash "${LIBRARY}" "${t}"
check "  ...and by restore" bash "${LIBRARY}" --restore "${t}"
check "  ...still a plain folder with nothing added" \
    bash -c "[ -d '${t}/tmp' ] && [ ! -L '${t}/tmp' ] && [ -z \"\$(ls -A '${t}/tmp')\" ]"

u=$(new_project foxtrot-disk)
ln -s "${DISK}/foxtrot" "${u}/tmp"
check "a door into a disk folder is refused" refuses "refusing to build scratch space on disk" bash "${LIBRARY}" "${u}"
check "  ...and nothing was built on disk" [ ! -e "${DISK}/foxtrot" ]

v=$(new_project golf-file)
printf 'not a folder\n' > "${EXEC_TIER_ROOT}/golf-file"
check "a file where the exec tier belongs is refused" refuses "is not a directory" bash "${LIBRARY}" "${v}"
check "  ...and the file survives" [ -f "${EXEC_TIER_ROOT}/golf-file" ]

w=$(new_project hotel-inner-folder)
mkdir -p "${EXEC_TIER_ROOT}/hotel-inner-folder/shared-memory"
ln -s "${EXEC_TIER_ROOT}/hotel-inner-folder" "${w}/tmp"
check "a real shared-memory folder is refused" refuses "is not a symlink" bash "${LIBRARY}" "${w}"

x=$(new_project india-inner-disk)
mkdir -p "${EXEC_TIER_ROOT}/india-inner-disk"
ln -s "${DISK}/india" "${EXEC_TIER_ROOT}/india-inner-disk/shared-memory"
ln -s "${EXEC_TIER_ROOT}/india-inner-disk" "${x}/tmp"
check "an inner door into a disk folder is refused" refuses "is not RAM" bash "${LIBRARY}" "${x}"

y=$(new_project juliet-dangling-tier)
ln -s "${SCRATCH}/nowhere" "${EXEC_TIER_ROOT}/juliet-dangling-tier"
check "a dangling symlink where the exec tier belongs is refused" \
    refuses "is a symlink to something that is not there" bash "${LIBRARY}" "${y}"

echo "executed form"
check "an unknown flag is refused, not treated as ensure" refuses "unknown option" bash "${LIBRARY}" --restroe "${p}"
check "no project is refused" refuses "exactly one project" bash "${LIBRARY}"
check "a missing folder is refused" refuses "not a folder" bash "${LIBRARY}" "${SCRATCH}/no-such"

echo "sourced form"
check "sourcing defines the functions and runs nothing" \
    bash -c "source '${LIBRARY}' && declare -F ensure_ram_tiers >/dev/null && declare -F restore_ram_tiers >/dev/null"
check "sourcing leaves the caller's DIR alone" \
    bash -c "DIR=/caller/own; source '${LIBRARY}'; [ \"\${DIR}\" = /caller/own ]"
check "a sourced refusal returns 1 without killing the caller's shell" \
    bash -c "source '${LIBRARY}'; restore_ram_tiers '${s}' 2>/dev/null; [ \$? -eq 1 ] && echo still-here | grep -q still-here"

echo "lua wrapper"
reboot
check "tiers.ensure rebuilds a project" \
    luajit -e "dofile('${LUA_LIBRARY}').ensure('${p}', '${DIR}')"
check "  ...laid out exactly" tiers_whole "${p}" alpha alpha
check "tiers.restore raises the library's own message" \
    bash -c "luajit -e \"dofile('${LUA_LIBRARY}').restore('${s}', '${DIR}')\" 2>&1 | grep -q 'never creates one'"
check "tiers.ensure with no folder raises" \
    bash -c "luajit -e \"dofile('${LUA_LIBRARY}').ensure(nil)\" 2>&1 | grep -q 'no project folder'"

echo "session-start hook"
reboot
check "from a subfolder, the hook finds the project and repairs it" hook_with "${p}/src"
check "  ...laid out exactly" tiers_whole "${p}" alpha alpha
check "  ...and printed nothing to stdout (which would enter the conversation)" [ -z "${HOOK_STDOUT}" ]
nolink="${SCRATCH}/not-a-project/deep"
mkdir -p "${nolink}"
check "where no project link sits above, the hook does nothing and succeeds" hook_with "${nolink}"
check "  ...and gave that folder no tmp link" [ ! -e "${SCRATCH}/not-a-project/tmp" ]
check "input that is not JSON is refused" \
    refuses "not JSON" bash -c "printf 'not json' | '${HOOK}' '${DIR}'"
check "input without a cwd is refused" \
    refuses "no cwd field" bash -c "printf '{}' | '${HOOK}' '${DIR}'"
check "a broken door is reported, not hidden" \
    refuses "refusing to build scratch space on disk" hook_with "${u}/src"

# A PATH with every tool the hook needs except jq, to prove that a missing jq is
# said out loud rather than passing silently as "tiers are fine".
nojq="${SCRATCH}/bin-without-jq"
mkdir -p "${nojq}"
for tool in bash cat dirname basename realpath readlink mkdir ln sed; do
    ln -s "$(command -v "${tool}")" "${nojq}/${tool}"
done
check "a missing jq is reported" \
    refuses "jq is not installed" env PATH="${nojq}" bash "${HOOK}" "${DIR}" < /dev/null

rm -rf "${SCRATCH}"
printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
