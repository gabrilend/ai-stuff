#!/usr/bin/env bash
# check-table-of-contents.test.sh -- proves the table-of-contents checker
# reports a listed path that does not exist and a document that is not listed,
# lets a listed folder cover the files inside it, and does not mistake a
# command written in backticks for a path. Runs the real checker against a
# throwaway project in RAM.
#
# Run: bash scripts/check-table-of-contents.test.sh [--dir PATH]

set -u
# The project folder: --dir PATH, or the path below; a stray word on the
# command line stops the script (libs/project-dir.sh, Issue 10-076).
source "$(dirname "$(readlink -f "$0")")/../libs/project-dir.sh"
project_dir_read "/mnt/mtwo/programming/ai-stuff/neocities-modernization" "" "$@"

"${DIR}/scripts/ensure-tmp-symlink" --dir "${DIR}" >/dev/null
SCRATCH="${DIR}/tmp/shared-memory/check-table-of-contents-test"
rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/docs/saved_files" "${SCRATCH}/notes"

pass=0; fail=0
# {{{ has / lacks
has() {
    if grep -q -x -- "$2" "${SCRATCH}/report.txt"; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1 (no line: $2)"; fi
}
lacks() {
    if grep -q -- "$2" "${SCRATCH}/report.txt"; then fail=$((fail+1)); echo "  FAIL - $1 (found: $2)"
    else pass=$((pass+1)); echo "  ok   - $1"; fi
}
# }}}

# {{{ the throwaway project
echo "listed" > "${SCRATCH}/docs/listed.md"
echo "forgotten" > "${SCRATCH}/docs/forgotten.md"
echo "inside a listed folder" > "${SCRATCH}/docs/saved_files/part.js"
echo "a note" > "${SCRATCH}/notes/idea"
cat > "${SCRATCH}/docs/table-of-contents.md" <<'EOF'
# Contents
- `/docs/listed.md` - exists
- `/docs/gone.md` - was deleted
- `/docs/saved_files/` - a folder
- `/notes/idea` - a note
- run `/usr/bin/some-tool <project> -m` for counts
EOF
git -C "${SCRATCH}" init -q
git -C "${SCRATCH}" add -A
# }}}

"${DIR}/scripts/check-table-of-contents" --dir "${SCRATCH}" > "${SCRATCH}/report.txt"
status=$?
if [ "${status}" -eq 1 ]; then pass=$((pass+1)); echo "  ok   - exits 1 with findings"
else fail=$((fail+1)); echo "  FAIL - exit status ${status}, want 1"; fi

has   "a listed path that is gone is reported"   "missing   /docs/gone.md"
has   "an unlisted document is reported"         "unlisted  /docs/forgotten.md"
lacks "a listed document is not reported"        "/docs/listed.md"
lacks "a listed folder covers its files"         "saved_files/part.js"
lacks "a backticked command is not a path"       "some-tool"
has   "exactly two findings"                     "2 finding(s)"

rm -rf "${SCRATCH}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
