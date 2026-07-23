#!/usr/bin/env bash
# test-seed-reproducibility.sh
#
# Issue 10-058 validator. In one sentence for the general: it proves that the
# word cloud's "random" word order is actually controlled by a single seed -- run
# it twice with the same seed and you get the exact same page; change the seed and
# the words rearrange. That is the whole promise of the reproducibility feature.
#
# WHAT IT CHECKS
#   1. Same --seed twice  -> byte-identical output/wordcloud.html (the strongest
#                            possible statement of determinism).
#   2. Different --seed    -> a genuinely DIFFERENT word order. Compared with the
#                            stamped seed-comment stripped out, so a pass means the
#                            ORDER changed, not merely the printed seed number.
#   3. The stamped seed in the page matches the --seed it was given (the "which
#      seed made this?" record travels with the artifact).
#
# HOW: runs src/wordcloud-generator.lua directly -- one cheap stage, no GPU, no
# embeddings -- snapshotting output/wordcloud.html between runs into tmp/ (RAM).
#
# REQUIRES assets/poems.json (run the extract stage first). Missing data is a hard
# error here, not a skipped check -- a test that silently passes on no data is worse
# than no test.
#
# Usage: scripts/test-seed-reproducibility.sh [DIR]
#   DIR defaults to the hard-coded project path; pass a path to run from anywhere.

set -u

# {{{ paths + preconditions
DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
GENERATOR="$DIR/src/wordcloud-generator.lua"
WORDCLOUD_HTML="$DIR/output/wordcloud.html"
POEMS_JSON="$DIR/assets/poems.json"
# Ephemeral snapshots go to the RAM-backed tmp/shared-memory/ tier (project convention).
SNAP_DIR="$DIR/tmp/shared-memory/seed-test"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$GENERATOR" ] || fail "generator not found at $GENERATOR"
[ -f "$POEMS_JSON" ] || fail "assets/poems.json not found -- run the extract stage first (this test needs real poems to shuffle)."

# tmp/ is a symlink into a RAM-backed dir that a reboot wipes, leaving the link
# dangling. Ensure its target exists before writing (project convention), via the
# canonical helper if present, else by creating the resolved target directly.
if [ -x "$DIR/scripts/ensure-tmp-symlink" ]; then
    "$DIR/scripts/ensure-tmp-symlink" "$DIR" >/dev/null 2>&1 || true
fi
TMP_TARGET="$(readlink -f "$DIR/tmp" 2>/dev/null || echo "$DIR/tmp")"
mkdir -p "$TMP_TARGET" || fail "could not create tmp target $TMP_TARGET"
mkdir -p "$SNAP_DIR" || fail "could not create snapshot dir $SNAP_DIR"
# }}}

# {{{ run_with_seed(seed, snapshot_name)
# Generate the word cloud with a fixed seed and copy the result aside. Errors if
# the generator did not actually (re)write the page.
run_with_seed() {
    local seed="$1"
    local snapshot="$2"
    luajit "$GENERATOR" "$DIR" --seed "$seed" >/dev/null || fail "generator exited non-zero for seed $seed"
    [ -f "$WORDCLOUD_HTML" ] || fail "generator produced no wordcloud.html for seed $seed"
    cp "$WORDCLOUD_HTML" "$SNAP_DIR/$snapshot" || fail "could not snapshot seed $seed"
}
# }}}

# {{{ strip_seed_comment(file) -> stdout
# Drop the three-line "<!-- Issue 10-058: ... -->" stamp so the order comparison
# reflects the WORD ORDER only, not the printed seed number.
strip_seed_comment() {
    grep -v -e 'Issue 10-058: word order shuffled' -e '^     --seed' -e 'output/generation-metadata.json. -->' "$1"
}
# }}}

echo "== Issue 10-058: word-cloud seed reproducibility =="

# {{{ check 1: same seed -> byte-identical
run_with_seed 12345 a-seed12345.html
run_with_seed 12345 b-seed12345.html
if cmp -s "$SNAP_DIR/a-seed12345.html" "$SNAP_DIR/b-seed12345.html"; then
    echo "PASS: same seed (12345) twice -> byte-identical word cloud"
else
    fail "same seed produced DIFFERENT output -- the shuffle is not deterministic"
fi
# }}}

# {{{ check 2: different seed -> different word order
run_with_seed 99999 c-seed99999.html
if strip_seed_comment "$SNAP_DIR/a-seed12345.html" > "$SNAP_DIR/a.body" \
   && strip_seed_comment "$SNAP_DIR/c-seed99999.html" > "$SNAP_DIR/c.body" \
   && cmp -s "$SNAP_DIR/a.body" "$SNAP_DIR/c.body"; then
    fail "different seeds (12345 vs 99999) produced the SAME word order -- the seed does not govern the shuffle"
else
    echo "PASS: different seed (99999) -> different word order"
fi
# }}}

# {{{ check 3: stamped seed matches the seed given
if grep -q "master seed 99999" "$SNAP_DIR/c-seed99999.html"; then
    echo "PASS: page stamps the seed it was built with (99999)"
else
    fail "page does not record its own seed -- the 'which seed made this?' stamp is missing"
fi
# }}}

echo "All seed-reproducibility checks passed."
