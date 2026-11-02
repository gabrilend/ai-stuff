#!/bin/bash
# project-discovery.sh - the bash face of libs/project-discovery.lua: which
# folders in a folder of projects are projects, how much each looks like one,
# and what kind each is. Meant to be *sourced*, not run.
#
# In plain terms: the rules live in one place, the Lua file beside this one,
# lifted out of delta-version/scripts/list-projects.sh (issue 010). These
# functions run it and put its answers into bash arrays, so a bash script
# gets exactly the answer a Lua script would, with no second copy of the
# rules to drift.
#
# Usage:
#
#   source "${SCRIPTS_DIR}/libs/project-discovery.sh"
#   project_discovery_init "/home/ritz/programming/ai-stuff"
#   project_discovery_scan || exit 1
#   for project in "${DISCOVERED_PROJECTS[@]}"; do
#       echo "$project: ${PROJECT_SCORES[$project]} (${PROJECT_TYPES[$project]})"
#   done
#
# Settings, read when project_discovery_scan or _score runs (set them after
# init, which resets them):
#
#   PROJECT_DISCOVERY_EXCLUDE=( glob ... )   more folder names to skip
#   PROJECT_DISCOVERY_ONLY_EXCLUDE=( ... )   the skipped names, replacing the
#                                            defaults entirely when non-empty
#   PROJECT_DISCOVERY_WEIGHTS=( mark=points ... )   change a mark's points
#   PROJECT_DISCOVERY_THRESHOLD=N            points a project needs (50)
#
# Needs luajit (the house interpreter); lua5.4 is used when luajit is absent.

PROJECT_DISCOVERY_LIB="$(dirname "${BASH_SOURCE[0]}")/project-discovery.lua"

# {{{ project_discovery_init()
# Sets the base folder and resets every setting and result.
project_discovery_init() {
   PROJECT_DISCOVERY_BASE="${1:-.}"
   PROJECT_DISCOVERY_EXCLUDE=()
   PROJECT_DISCOVERY_ONLY_EXCLUDE=()
   PROJECT_DISCOVERY_WEIGHTS=()
   PROJECT_DISCOVERY_THRESHOLD=""
   DISCOVERED_PROJECTS=()
   declare -gA PROJECT_SCORES=()
   declare -gA PROJECT_TYPES=()
}
# }}}

# {{{ _project_discovery_run()
# Runs the Lua rulebook with the current settings appended.
_project_discovery_run() {
   local lua=luajit
   command -v luajit > /dev/null || lua=lua5.4
   local args=("$@") g w
   for g in "${PROJECT_DISCOVERY_EXCLUDE[@]}"; do args+=(--exclude "$g"); done
   for g in "${PROJECT_DISCOVERY_ONLY_EXCLUDE[@]}"; do args+=(--only-exclude "$g"); done
   for w in "${PROJECT_DISCOVERY_WEIGHTS[@]}"; do args+=(--weight "$w"); done
   [ -n "${PROJECT_DISCOVERY_THRESHOLD}" ] && args+=(--threshold "${PROJECT_DISCOVERY_THRESHOLD}")
   "$lua" "${PROJECT_DISCOVERY_LIB}" "${args[@]}"
}
# }}}

# {{{ project_discovery_scan()
# Fills DISCOVERED_PROJECTS (paths, sorted by name), PROJECT_SCORES[path] and
# PROJECT_TYPES[path]. Fails, saying why, when the rulebook fails; an empty
# folder is not a failure, just no projects.
project_discovery_scan() {
   [ -n "${PROJECT_DISCOVERY_BASE:-}" ] || project_discovery_init "."
   DISCOVERED_PROJECTS=()
   PROJECT_SCORES=()
   PROJECT_TYPES=()
   local listing path name score type
   listing="$(_project_discovery_run scan "${PROJECT_DISCOVERY_BASE}")" || return 1
   while IFS=$'\t' read -r path name score type; do
      [ -n "$path" ] || continue
      DISCOVERED_PROJECTS+=("$path")
      PROJECT_SCORES["$path"]="$score"
      PROJECT_TYPES["$path"]="$type"
   done <<< "$listing"
}
# }}}

# {{{ project_discovery_score()
# Prints a folder's score, whether or not it reaches the threshold.
project_discovery_score() {
   _project_discovery_run score "$1"
}
# }}}

# {{{ project_discovery_classify()
# Prints a folder's kind: rust, go, node, python, lua, c, c++, shell, zig, or
# unknown.
project_discovery_classify() {
   _project_discovery_run classify "$1"
}
# }}}

# {{{ project_discovery_is_project()
# Succeeds when the folder is a project: its name is not a skipped one and its
# score reaches the threshold.
project_discovery_is_project() {
   local dir="${1%/}" parent row
   parent="$(dirname "$dir")"
   # the scan names each folder as parent/name, so this one is asked for so
   row="$(_project_discovery_run scan "$parent" --all \
      | awk -F'\t' -v p="${parent}/$(basename "$dir")" '$1 == p { print $5 }')"
   [ "$row" = "project" ]
}
# }}}
