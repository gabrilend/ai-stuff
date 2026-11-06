#!/usr/bin/env bash
# test-git-history-update.sh -- checks git-history.sh's --update mode (issue
# A01, step 8: incremental updates).
#
# --update keeps what an existing phase file already says about each commit
# and formats only the commits it lacks. The checks:
#   - after new commits, an update writes the same file a full run would
#     (apart from the "Generated:" time), with and without statistics;
#   - it really reuses the old text: a word changed by hand inside an old
#     commit's section survives the update, and a full run puts it back;
#   - a commit from a branch merged later lands in date order, not at the top;
#   - --update with no file yet is a full run, and the report counts the new
#     commits.
#
# Everything happens in a git repository made in a temp folder.
# Usage: bash scripts/tests/test-git-history-update.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
WORK="$(mktemp -d /tmp/test-git-history-update-XXXXXX)"
REPO="$WORK/repo"
OUT="$WORK/out"

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# {{{ commit_issue <file> <message> <date>
# Writes a line into issues/<file> and commits it at the given date, so the
# order of commits is fixed whatever the clock says.
commit_issue() {
    mkdir -p "$REPO/proj/issues/$(dirname "$1")"
    echo "$2" >> "$REPO/proj/issues/$1"
    git -C "$REPO" add -A
    GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" \
        git -C "$REPO" commit -q -m "$2"
}
# }}}

# {{{ history <args...>
# Runs git-history.sh on the project into $OUT; prints its report.
history() {
    bash "$DIR/git-history.sh" -d "$REPO/proj" -o "$OUT" "$@" 2>&1
}
# }}}

# {{{ same_but_time <a> <b>
# yes when two phase files match line for line, the "Generated:" line aside.
same_but_time() {
    if diff <(grep -v '^Generated: ' "$1") <(grep -v '^Generated: ' "$2") >/dev/null; then
        echo yes
    else
        echo no
    fi
}
# }}}

git init -q -b main "$REPO"
git -C "$REPO" config user.name "Test"
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config commit.gpgsign false

commit_issue "101-first.md" "Phase one starts" "2026-01-01T10:00:00"
commit_issue "102-second.md" "Phase one goes on" "2026-01-02T10:00:00"
commit_issue "201-other.md" "Phase two starts" "2026-01-03T10:00:00"

# {{{ --update with no file yet is a full run
report="$(history -a -u)"
check "first --update writes phase 1" "$(grep -c '^## \[' "$OUT/phase-1-commits.md")" "2"
check "first --update counts every commit as new" \
    "$(grep -c 'phase-1-commits.md (2 commits, 2 new)' <<< "$report")" "1"
# }}}

# {{{ new commits: update matches a full run
commit_issue "103-third.md" "Phase one, third piece" "2026-01-04T10:00:00"
commit_issue "completed/101-first.md" "Phase one, first piece done" "2026-01-05T10:00:00"

report="$(history -a --update)"
check "update reports two new commits for phase 1" \
    "$(grep -c 'phase-1-commits.md (4 commits, 2 new)' <<< "$report")" "1"
check "update reports none new for phase 2" \
    "$(grep -c 'phase-2-commits.md (1 commits, 0 new)' <<< "$report")" "1"
cp "$OUT/phase-1-commits.md" "$WORK/updated.md"
history -a > /dev/null
check "the updated file matches a full run" "$(same_but_time "$WORK/updated.md" "$OUT/phase-1-commits.md")" "yes"
check "newest commit first" "$(grep -m1 '^## \[' "$OUT/phase-1-commits.md" | sed 's/^## \[[0-9a-f]*\] //')" \
    "Phase one, first piece done"
# }}}

# {{{ old sections are reused, not rewritten
sed -i 's/^## \(\[[0-9a-f]*\]\) Phase one goes on$/## \1 Phase one goes on (edited by hand)/' "$OUT/phase-1-commits.md"
commit_issue "104-fourth.md" "Phase one, fourth piece" "2026-01-06T10:00:00"
history -a -u > /dev/null
check "a hand edit in an old section survives --update" \
    "$(grep -c 'Phase one goes on (edited by hand)' "$OUT/phase-1-commits.md")" "1"
check "the new commit is there" "$(grep -c 'Phase one, fourth piece' "$OUT/phase-1-commits.md")" "1"
check "the header total counts it" "$(grep -c '^Total: 5 commits' "$OUT/phase-1-commits.md")" "1"
history -a > /dev/null
check "a full run writes the section afresh" \
    "$(grep -c 'edited by hand' "$OUT/phase-1-commits.md")" "0"
# }}}

# {{{ a branch merged later lands in date order
git -C "$REPO" checkout -q -b side "HEAD~3"
commit_issue "105-side.md" "Phase one, side branch work" "2026-01-03T12:00:00"
git -C "$REPO" checkout -q main
GIT_AUTHOR_DATE="2026-01-07T10:00:00" GIT_COMMITTER_DATE="2026-01-07T10:00:00" \
    git -C "$REPO" merge -q --no-edit side
history -a -s -u > /dev/null
cp "$OUT/phase-1-commits.md" "$WORK/updated-stats.md"
history -a -s > /dev/null
check "with a merged branch and --stats, update matches a full run" \
    "$(same_but_time "$WORK/updated-stats.md" "$OUT/phase-1-commits.md")" "yes"
check "the side-branch commit is not first" \
    "$(grep -m1 '^## \[' "$WORK/updated-stats.md" | grep -c 'side branch')" "0"
check "statistics are written" "$(grep -c '^| Commits | 6 |' "$WORK/updated-stats.md")" "1"
# }}}

# {{{ an interrupted run leaves no stray file
check "no temp files left in the output folder" "$(ls "$OUT" | grep -c '\.new\.')" "0"
# }}}

rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
