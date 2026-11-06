#!/usr/bin/env bash
#
# test-project-discovery.sh
#
# Proves that libs/project-discovery.lua and its bash face find the projects
# in a folder the way delta-version/scripts/list-projects.sh does, score and
# classify them, and take their settings (issue 010).
#
# In general terms: it builds a small shelf of fake projects in a scratch
# folder -- some that should count, some just under the line, some whose
# names rule them out -- then asks the Lua library, its command form under
# both luajit and lua5.4, and the bash functions, and checks that all three
# give the same answers.
#
# Usage: test-project-discovery.sh [scripts-directory]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
LIB="${DIR}/libs/project-discovery.lua"
SHELF="$(mktemp -d "${TMPDIR:-/tmp}/test-project-discovery-XXXXXX")"
trap 'rm -rf "${SHELF}"' EXIT

failures=0
checked=0

# {{{ check()
check() {
    local description="$1" result="$2"
    checked=$((checked + 1))
    if [ "${result}" = "yes" ]; then
        printf '  ok       %s\n' "${description}"
    else
        printf '  FAILED   %s\n' "${description}"
        failures=$((failures + 1))
    fi
}
# }}}

# {{{ same()
# Prints yes when the two arguments are equal, and shows both when not.
same() {
    if [ "$1" = "$2" ]; then printf yes; else printf 'no\n    got:  %s\n    want: %s' "$1" "$2"; fi
}
# }}}

# {{{ the shelf
# A folder of folders, each built to sit on one side of one rule.
mk() { mkdir -p "${SHELF}/$1"; }
touchf() { mkdir -p "$(dirname "${SHELF}/$1")"; : > "${SHELF}/$1"; }

mk lua-game/src;        touchf lua-game/src/main.lua; touchf lua-game/src/ui.lua; touchf lua-game/run.sh
mk rusty/src;           touchf rusty/Cargo.toml; touchf rusty/src/main.rs           # src + Cargo = 80
mk node-thing;          touchf node-thing/package.json; touchf node-thing/.gitignore  # 30 + 20 = 50, on the line
mk almost;              touchf almost/package.json; touchf almost/README.md         # 30 + 15 = 45, under it
mk planning/issues;     mk planning/docs                                            # 40 + 10 = 50, docs only
mk c-tool/src;          touchf c-tool/Makefile; touchf c-tool/src/a.c; touchf c-tool/src/a.h; touchf c-tool/src/b.c; touchf c-tool/src/x.lua
mk tie/src;             touchf tie/src/a.sh; touchf tie/src/b.lua                   # one each: lua before shell
mk build/src;           mk build/issues                                             # 90 points, but named build
mk .storage_old/src;    mk .storage_old/issues                                      # a glob-excluded name
mk node_modules/src                                                                 # excluded by name
mk empty                                                                            # nothing at all
touchf README.md; mk src                                                            # the shelf itself scores 50+...
ln -s "${SHELF}/lua-game" "${SHELF}/linked-game"                                    # a link to a project
# ...but "src" directly on the shelf is a folder of its own: src/ has no marks
# }}}

expected_projects="c-tool lua-game node-thing planning rusty tie"

printf '\nThe Lua library, loaded with dofile\n'
got="$(luajit - "${LIB}" "${SHELF}" <<'EOF'
local d = dofile(arg[1])
d.init(arg[2])
local names = {}
for _, p in ipairs(d.scan()) do names[#names + 1] = p.name .. "=" .. p.score .. ":" .. p.type end
print(table.concat(names, " "))
EOF
)"
check "finds exactly the projects, sorted, with scores and kinds" "$(same "${got}" \
    "c-tool=75:c lua-game=50:lua node-thing=50:node planning=50:unknown rusty=80:rust tie=50:lua")"
check "loading it with dofile runs nothing by itself" \
    "$( [ "$(luajit -e "dofile('${LIB}')" 2>&1)" = "" ] && echo yes || echo no)"

for LUA in luajit lua5.4; do
    printf '\nThe command form under %s\n' "${LUA}"
    names="$("${LUA}" "${LIB}" scan "${SHELF}" | cut -f2 | tr '\n' ' ' | sed 's/ $//')"
    check "scan lists the projects" "$(same "${names}" "${expected_projects}")"
    check "a score exactly at the threshold counts; one under it does not" \
        "$(grep -qw node-thing <<< "${names}" && ! grep -qw almost <<< "${names}" && echo yes || echo no)"
    check "a name that rules a folder out wins over its score" \
        "$(! grep -qwE 'build|node_modules|\.storage_old' <<< "${names}" && echo yes || echo no)"
    check "the shelf itself and a link to a project are not listed" \
        "$(! grep -qwE 'linked-game' <<< "${names}" && ! "${LUA}" "${LIB}" scan "${SHELF}" | cut -f1 | grep -qx "${SHELF}" && echo yes || echo no)"
    all="$("${LUA}" "${LIB}" scan "${SHELF}" --all)"
    check "--all marks the rest as not-project or excluded" "$(same \
        "$(awk -F'\t' '$2=="almost"||$2=="build"||$2=="empty"{print $2"="$5}' <<< "${all}" | tr '\n' ' ')" \
        "almost=not-project build=excluded empty=not-project ")"
    check "score of one folder" "$(same "$("${LUA}" "${LIB}" score "${SHELF}/almost")" 45)"
    check "a build file settles the kind" "$(same "$("${LUA}" "${LIB}" classify "${SHELF}/rusty")" rust)"
    check "otherwise the most common source kind does (3 C files to 1 Lua)" \
        "$(same "$("${LUA}" "${LIB}" classify "${SHELF}/c-tool")" c)"
    check "a tie goes to the kind first in alphabetical order" \
        "$(same "$("${LUA}" "${LIB}" classify "${SHELF}/tie")" lua)"
    check "no source at all is unknown" "$(same "$("${LUA}" "${LIB}" classify "${SHELF}/empty")" unknown)"
    check "--threshold raises the line" "$(same \
        "$("${LUA}" "${LIB}" scan "${SHELF}" --threshold 75 | cut -f2 | tr '\n' ' ')" "c-tool rusty ")"
    check "--weight changes a mark's points" "$(same \
        "$("${LUA}" "${LIB}" scan "${SHELF}" --weight README.md=20 | cut -f2 | grep -c almost)" 1)"
    check "--exclude adds a name to skip" "$(same \
        "$("${LUA}" "${LIB}" scan "${SHELF}" --exclude 'r*' | cut -f2 | tr '\n' ' ')" "c-tool lua-game node-thing planning tie ")"
    check "--only-exclude replaces the skipped names" \
        "$("${LUA}" "${LIB}" scan "${SHELF}" --only-exclude nothing | cut -f2 | grep -qx build && echo yes || echo no)"
    "${LUA}" "${LIB}" scan "${SHELF}/nowhere" > /dev/null 2>&1; status=$?
    check "a base that is not a folder is refused" "$( [ ${status} = 2 ] && echo yes || echo no)"
done

printf '\nThe bash face\n'
# shellcheck source=/dev/null
source "${DIR}/libs/project-discovery.sh"
project_discovery_init "${SHELF}"
project_discovery_scan; status=$?
names=""
for p in "${DISCOVERED_PROJECTS[@]}"; do names+="$(basename "$p")=${PROJECT_SCORES[$p]}:${PROJECT_TYPES[$p]} "; done
check "scan fills the three arrays as the library answers" "$( [ ${status} = 0 ] && same "${names}" \
    "c-tool=75:c lua-game=50:lua node-thing=50:node planning=50:unknown rusty=80:rust tie=50:lua " || echo no)"
check "project_discovery_score" "$(same "$(project_discovery_score "${SHELF}/rusty")" 80)"
check "project_discovery_classify" "$(same "$(project_discovery_classify "${SHELF}/node-thing")" node)"
check "project_discovery_is_project says yes to a project" \
    "$(project_discovery_is_project "${SHELF}/rusty" && echo yes || echo no)"
check "...and no to an excluded one and one under the line" \
    "$(! project_discovery_is_project "${SHELF}/build" && ! project_discovery_is_project "${SHELF}/almost/" && echo yes || echo no)"
PROJECT_DISCOVERY_EXCLUDE=("tie" "c-*")
PROJECT_DISCOVERY_THRESHOLD=50
project_discovery_scan
check "settings set after init are used by the next scan" "$(same "${#DISCOVERED_PROJECTS[@]}" 4)"
project_discovery_init "${SHELF}"
project_discovery_scan
check "init resets the settings" "$(same "${#DISCOVERED_PROJECTS[@]}" 6)"
project_discovery_init "${SHELF}/nowhere"
project_discovery_scan 2> /dev/null; status=$?
check "a failed scan fails, and leaves no stale results" \
    "$( [ ${status} != 0 ] && [ ${#DISCOVERED_PROJECTS[@]} = 0 ] && echo yes || echo no)"

printf '\n%d checks, %d failures\n' "${checked}" "${failures}"
[ "${failures}" -eq 0 ]
