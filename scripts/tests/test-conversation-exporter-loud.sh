#!/usr/bin/env bash
#
# test-conversation-exporter-loud.sh - proves claude-conversation-exporter.sh
# shows a failed transcript export instead of hiding it (issue 034).
#
# In plain terms: when a project has no llm-transcripts/ folder yet, the
# exporter runs a backup tool to make one. It used to run that tool with its
# error messages thrown away and its failure ignored, so a broken export
# looked exactly like a project with no conversations. This test gives
# scratch projects a stand-in backup tool -- one that fails with a message,
# one that succeeds and writes down how it was called, and an older-style
# backup-conversations.sh -- and runs the exporter on each. It checks that a
# failure's own message reaches the screen with the project and exit status
# named, that a success is not reported as a failure, and that the tool is
# run as a program with --all and the project, not sourced, with its output
# on stderr so the exporter's stdout holds only conversations. No real
# conversations are read: the stand-ins never look at ~/.claude.
#
# Usage:
#   tests/test-conversation-exporter-loud.sh [scripts-dir]

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

EXPORTER="${DIR}/claude-conversation-exporter.sh"
SCRATCH="$(mktemp -d /tmp/claude-1000/test-exporter-loud.XXXXXX)"

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

# {{{ says
# says <text> <file>: the file holds the text (fixed string).
says() { grep -qF -- "$1" "$2" || { printf '        (not said: %s)\n' "$1"; sed 's/^/        | /' "$2" | head -8; return 1; }; }
# }}}

# {{{ export_all
# export_all <project>: runs the exporter's "all" command on the project,
# keeping what it wrote to stderr in <project>.err.
export_all() {
    "${EXPORTER}" "$1" all >"$1.out" 2>"$1.err" </dev/null
}
# }}}

printf '\nA backup tool that fails\n'
broken="${SCRATCH}/broken"
mkdir -p "${broken}/scripts"
cat > "${broken}/scripts/backup-conversations" <<'EOF'
#!/bin/bash
echo "stand-in: no session folder for this project" >&2
exit 3
EOF
export_all "${broken}"
check "the tool's own message reaches the screen" \
    says "stand-in: no session folder for this project" "${broken}.err"
check "the exporter names the project and the exit status" \
    says "exporting ${broken} failed (exit 3" "${broken}.err"

printf '\nA backup tool that succeeds\n'
working="${SCRATCH}/working"
mkdir -p "${working}/scripts"
cat > "${working}/scripts/backup-conversations" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$(pwd)/called-with"
echo "stand-in: swept 0 conversations"
EOF
export_all "${working}"
check "it is run as a program with --all and the project" \
    test "$(tr '\n' ' ' < "${working}/called-with" 2>/dev/null)" = "--all ${working} "
check "it is run from inside the project" test -f "${working}/called-with"
check "a success is not reported as a failure" \
    bash -c '! grep -q "failed (exit" "$1"' _ "${working}.err"
check "the tool's output goes to stderr, keeping stdout for the conversations" \
    bash -c 'grep -qF "stand-in: swept" "$1" && ! grep -qF "stand-in: swept" "$2"' _ "${working}.err" "${working}.out"

printf '\nAn older project with backup-conversations.sh\n'
older="${SCRATCH}/older"
mkdir -p "${older}"
cat > "${older}/backup-conversations.sh" <<'EOF'
#!/bin/bash
echo "stand-in: the old script broke" >&2
exit 2
EOF
export_all "${older}"
check "its failure is shown too" \
    bash -c 'grep -qF "stand-in: the old script broke" "$1" && grep -qF "failed (exit 2" "$1"' _ "${older}.err"

rm -rf "${SCRATCH}"
printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
