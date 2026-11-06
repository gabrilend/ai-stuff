#!/bin/bash
# issue-manager.sh - the bash face of libs/issue-manager.lua: the everyday
# operations on a project's issue files. Meant to be *sourced*, not run.
#
# In plain terms: the rules for reading issue names live in
# libs/issue-names.lua and the rules for a well-formed issue in
# validate-issues; libs/issue-manager.lua puts them behind one set of
# operations, and these functions run it (issue 012). Nothing here stages or
# commits: a completed issue is moved on disk and the commit route picks the
# move up from the files.
#
# Usage:
#
#   source "${SCRIPTS_DIR}/libs/issue-manager.sh"
#   issue_init "/path/to/project" || exit 1
#   next_id=$(issue_get_next_id 3)                      # "308" if 307 exists
#   issue_create "$next_id" "implement-feature" <<'BODY'
#   ## Current Behavior
#   ...
#   BODY
#   issue_list open 3                                   # id, phase, status, path
#   issue_complete "$next_id"
#
# Every function prints its answer on stdout and its reason for refusing on
# stderr, and returns non-zero when it refused.

ISSUE_MANAGER_LIB="$(dirname "${BASH_SOURCE[0]}")/issue-manager.lua"

# {{{ _issue_manager_run()
_issue_manager_run() {
   local lua=luajit
   command -v luajit > /dev/null || lua=lua5.4
   "$lua" "${ISSUE_MANAGER_LIB}" "${ISSUE_MANAGER_PROJECT:?call issue_init first}" "$@"
}
# }}}

# {{{ issue_init()
# Sets the project. Fails when it has no issues/ folder.
issue_init() {
   ISSUE_MANAGER_PROJECT="${1:-.}"
   if [ ! -d "${ISSUE_MANAGER_PROJECT}/issues" ]; then
      echo "no issues directory at ${ISSUE_MANAGER_PROJECT}/issues" >&2
      return 2
   fi
}
# }}}

# {{{ issue_get_next_id()
# The id a new issue in PHASE takes, in the project's own shape.
issue_get_next_id() { _issue_manager_run next "${1:?phase}"; }
# }}}

# {{{ issue_list()
# One line per issue: id, phase, status, path under issues/ (tab-separated).
# Optional STATUS (open, completed, retired, unknown; "" for any) and PHASE.
issue_list() {
   local args=()
   [ -n "${1:-}" ] && args+=(--status "$1")
   [ -n "${2:-}" ] && args+=(--phase "$2")
   _issue_manager_run list "${args[@]}"
}
# }}}

# {{{ issue_path()
# The full path of the issue with this id.
issue_path() { _issue_manager_run show "${1:?id}"; }
# }}}

# {{{ issue_create()
# Writes issues/ID-NAME.md and prints its path. The body is read from standard
# input when it is not a terminal; when that is a terminal, or nothing arrives
# on it, the file gets a template with the three required headings.
issue_create() {
   local id="${1:?id}" name="${2:?name}"
   if [ -t 0 ]; then
      _issue_manager_run create "$id" "$name"
   else
      _issue_manager_run create "$id" "$name" -
   fi
}
# }}}

# {{{ issue_complete()
# Moves an open issue into issues/completed/ and prints its new path.
issue_complete() { _issue_manager_run complete "${1:?id}"; }
# }}}

# {{{ issue_validate()
# Prints validate-issues' findings for one issue; succeeds when there are none.
issue_validate() { _issue_manager_run validate "${1:?id}"; }
# }}}

# {{{ issue_search()
# Lines containing every given word, case ignored: path:line: text.
issue_search() { _issue_manager_run search "$@"; }
# }}}
