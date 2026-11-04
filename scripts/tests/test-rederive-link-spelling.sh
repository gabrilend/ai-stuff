#!/bin/bash
#
# test-rederive-link-spelling.sh
#
# Checks that rederive-transcripts rebuilds a transcript whose session was
# started through a link to its project folder (issue 040).
#
# In general terms: Claude files a session's log under the name of the folder
# it was started in, as spelled. Start it through a shortcut -- a link such as
# /mnt/mtwo/programs/claude-code standing for /mnt/mtwo/.claude/claude-code --
# and the log is filed under the shortcut's name, where a rebuild that only
# looks under the real name never finds it. That left a whole folder's
# transcripts unrebuilt for weeks. This builds a throwaway project, a link to
# it, and a log filed under the link's name, and asks the rebuild what it
# would do.
#
# Usage: test-rederive-link-spelling.sh [scripts-dir]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
TMP="${TMPDIR:-/tmp}/rederive-link-spelling-$$"
FAILURES=0

# -- {{{ check
check() {
   if [ "$1" = "true" ]; then
      echo "  ok   - $2"
   else
      echo "  FAIL - $2"
      FAILURES=$((FAILURES + 1))
   fi
}
# }}}

mkdir -p "$TMP/disk/real/proj/llm-transcripts" "$TMP/sessions"
ln -s "$TMP/disk/real/proj" "$TMP/disk/shortcut"
printf '# Conversation Summary: s-linked\n\nGenerated on: now\n' > "$TMP/disk/real/proj/llm-transcripts/sep-1-26.md"
LINK_DIR="$TMP/sessions/$(printf '%s' "$TMP/disk/shortcut" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$LINK_DIR"
printf '{"type":"user","cwd":"%s","timestamp":"2026-09-01T10:00:00Z"}\n' "$TMP/disk/shortcut" > "$LINK_DIR/s-linked.jsonl"

report=$(TRANSCRIPT_SEARCH_ROOTS="$TMP/disk" CLAUDE_SESSIONS_ROOT="$TMP/sessions" \
   "$DIR/rederive-transcripts" 2>&1)

check "$(echo "$report" | grep -q 'Transcripts whose conversation log survives: *1' && echo true)" \
   "the transcript's log is found, under the link's name"
check "$(echo "$report" | grep -q "as $TMP/disk/shortcut\$" && echo true)" \
   "the project is also swept under the link's spelling"
check "$(echo "$report" | grep -q "Folders also swept under a link's spelling: *1" && echo true)" \
   "... and counted"

rm -rf "$TMP"

echo ""
if [ "$FAILURES" -eq 0 ]; then
   echo "PASS: all checks passed"
   exit 0
fi
echo "FAIL: $FAILURES check(s) failed"
exit 1
