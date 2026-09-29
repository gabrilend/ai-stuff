#!/bin/bash
# test-census-projects.sh - proves the census can keep the front page honest.
#
# In general terms: the census now rewrites the figures on the repository's
# front page by itself. This test works only on copies in a scratch folder,
# never on the real page, and checks the promises that make that safe: a
# second rewrite changes nothing, a figure it does not recognise stops it
# with the page untouched, a marker left open stops it, a stale page is
# reported, numbers are spelled correctly, and options work in any order.
# Exercises the success criteria of issue 058.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

CENSUS="$DIR/delta-version/scripts/census-projects.lua"
# Copies live in guaranteed RAM, through the project's tmp/ door.
SCRATCH="$DIR/delta-version/tmp/shared-memory/census-test"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    # One line per assertion; failures keep going so a run reports everything.
    local label="$1" ok="$2"
    if [ "$ok" = "yes" ]; then
        echo "  ok   - $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $label"
        FAIL=$((FAIL + 1))
    fi
}
# }}}

# -- {{{ prepare_scratch
function prepare_scratch() {
    # A reboot empties RAM and leaves the tmp/ symlink pointing at nothing;
    # the shared library rebuilds the rooms behind it before anything writes.
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    mkdir -p "$SCRATCH"
}
# }}}

# -- {{{ test_number_words
function test_number_words() {
    local expected=( "0:zero" "13:thirteen" "20:twenty" "21:twenty-one"
                     "72:seventy-two" "91:ninety-one" "100:one hundred"
                     "118:one hundred and eighteen" "999:nine hundred and ninety-nine" )
    local pair number words said
    for pair in "${expected[@]}"; do
        number="${pair%%:*}"
        words="${pair#*:}"
        said=$(luajit "$CENSUS" --say="$number")
        check "$number is said as \"$words\"" "$([ "$said" = "$words" ] && echo yes || echo no)"
    done
    luajit "$CENSUS" --say=1000 > /dev/null 2>&1
    check "1000 is refused, not written as digits" "$([ $? -ne 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_rewrite_converges
function test_rewrite_converges() {
    # A stale copy of the real page, rewritten, then checked: the check must
    # pass, and a second rewrite must leave the bytes identical.
    local copy="$SCRATCH/converge.md"
    cp "$DIR/README.md" "$copy"
    sed -i 's|<!-- census:projects:words -->[^<]*<!-- /census -->|<!-- census:projects:words -->seven<!-- /census -->|' "$copy"

    luajit "$CENSUS" --check-readme --readme="$copy" > /dev/null 2>&1
    check "a stale copy fails the check" "$([ $? -eq 1 ] && echo yes || echo no)"

    luajit "$CENSUS" --write-readme --readme="$copy" > /dev/null 2>&1
    local first_sum
    first_sum=$(sha256sum "$copy")
    luajit "$CENSUS" --check-readme --readme="$copy" > /dev/null 2>&1
    check "a rewritten copy passes the check" "$([ $? -eq 0 ] && echo yes || echo no)"

    luajit "$CENSUS" --write-readme --readme="$copy" > /dev/null 2>&1
    check "a second rewrite changes nothing" "$([ "$(sha256sum "$copy")" = "$first_sum" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_refusals_leave_file_untouched
function test_refusals_leave_file_untouched() {
    local copy="$SCRATCH/refuse.md" before
    local cases=(
        "unknown slot:before <!-- census:nonsense:digits -->1<!-- /census --> after"
        "unknown format:before <!-- census:projects:roman -->XC<!-- /census --> after"
        "unclosed marker:before <!-- census:projects:digits -->90 and no end"
        "unknown project:<!-- census:total@no-such-project:digits -->1<!-- /census -->"
    )
    local entry label body
    for entry in "${cases[@]}"; do
        label="${entry%%:*}"
        body="${entry#*:}"
        printf '%s\n' "$body" > "$copy"
        before=$(sha256sum "$copy")
        luajit "$CENSUS" --write-readme --readme="$copy" > /dev/null 2>&1
        local code=$?
        check "$label is refused" "$([ $code -ne 0 ] && echo yes || echo no)"
        check "$label leaves the file byte-identical" "$([ "$(sha256sum "$copy")" = "$before" ] && echo yes || echo no)"
    done
}
# }}}

# -- {{{ test_option_order
function test_option_order() {
    # --dir= used to be read only in first position; after the mode it was
    # silently ignored and the census counted the wrong tree.
    local before after
    before=$(luajit "$CENSUS" --dir="$DIR/delta-version" --json | head -2)
    after=$(luajit "$CENSUS" --json --dir="$DIR/delta-version" | head -2)
    check "--dir= means the same before or after the mode" "$([ "$before" = "$after" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_pre_commit_hook
function test_pre_commit_hook() {
    # The hook reads whatever staging list GIT_INDEX_FILE names, so each case
    # builds a private one in RAM from the last commit -- the shared staging
    # area other sessions use is never touched. Hashing a README version
    # writes a loose object into the repository, which is harmless.
    local hook="$DIR/delta-version/scripts/hooks/pre-commit"
    local index="$SCRATCH/hook-index"
    local stale="$SCRATCH/hook-stale.md" blob

    rm -f "$index"
    GIT_INDEX_FILE="$index" git -C "$DIR" read-tree HEAD
    GIT_INDEX_FILE="$index" "$hook" > /dev/null 2>&1
    check "a commit without README.md is let through" "$([ $? -eq 0 ] && echo yes || echo no)"

    local current="$SCRATCH/hook-current.md"
    cp "$DIR/README.md" "$current"
    luajit "$CENSUS" --write-readme --readme="$current" > /dev/null 2>&1
    blob=$(git -C "$DIR" hash-object -w "$current")
    GIT_INDEX_FILE="$index" git -C "$DIR" update-index --cacheinfo "100644,$blob,README.md"
    GIT_INDEX_FILE="$index" "$hook" > /dev/null 2>&1
    check "a current README.md is let through" "$([ $? -eq 0 ] && echo yes || echo no)"

    sed 's|<!-- census:projects:words -->[^<]*<!-- /census -->|<!-- census:projects:words -->seven<!-- /census -->|' "$current" > "$stale"
    blob=$(git -C "$DIR" hash-object -w "$stale")
    GIT_INDEX_FILE="$index" git -C "$DIR" update-index --cacheinfo "100644,$blob,README.md"
    GIT_INDEX_FILE="$index" "$hook" > /dev/null 2>&1
    check "a stale README.md is refused" "$([ $? -eq 1 ] && echo yes || echo no)"
    rm -f "$index" "$stale" "$current"
}
# }}}

# -- {{{ test_real_page_current
function test_real_page_current() {
    # Informational for the deployment run: the real page should be current
    # right after a rewrite. Reported, and counted, like the rest.
    luajit "$CENSUS" --check-readme > /dev/null 2>&1
    check "the real front page is current" "$([ $? -eq 0 ] && echo yes || echo no)"
}
# }}}

prepare_scratch
echo "census-projects"
test_number_words
test_rewrite_converges
test_refusals_leave_file_untouched
test_option_order
test_pre_commit_hook
test_real_page_current
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
