#!/usr/bin/env bash
# ensure-site-in-ram.test.sh (Issue 10-072) -- proves the site-in-RAM layout
# is made correctly, survives a simulated logout, refuses to bury a real
# folder, and that the page check still finds pages through the linked site
# folder. Works in a scratch project inside RAM, so the real site is never
# touched.
# Run: bash scripts/ensure-site-in-ram.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
"$DIR/scripts/ensure-tmp-symlink" "$DIR" >/dev/null
SCRATCH="$DIR/tmp/shared-memory/ensure-site-in-ram-test"
rm -rf "$SCRATCH"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ a scratch project with an old-style on-disk site
# Its own tmp/shared-memory/ is a plain folder: the helper only needs it to
# exist, and a plain folder keeps the test away from the real RAM tier.
P="$SCRATCH/project"
mkdir -p "$P/tmp/shared-memory" "$P/output/media/my-art" "$P/output/similar"
echo 'picture' > "$P/output/media/my-art/a.png"
echo '<html><pre>old page</pre></html>' > "$P/output/similar/0001-01.html"
# }}}

# {{{ a real folder is refused without --migrate
out=$("$DIR/scripts/ensure-site-in-ram" "$P" 2>&1)
check "real output/ folder: refused" "$?" "1"
check "refusal names --migrate" "$(printf '%s' "$out" | grep -c -- '--migrate')" "1"
check "real output/ left as it was" "$([ -d "$P/output" ] && [ ! -L "$P/output" ] && echo yes)" "yes"
# }}}

# {{{ --migrate moves pictures to disk, keeps the old site, makes the layout
"$DIR/scripts/ensure-site-in-ram" "$P" --migrate >/dev/null 2>&1
check "migrate: exits cleanly" "$?" "0"
check "output/ is now a link" "$([ -L "$P/output" ] && echo yes)" "yes"
check "output/ points into RAM" "$(readlink "$P/output")" "tmp/shared-memory/site"
check "pictures moved to the disk folder" "$(cat "$P/assets/site-media/my-art/a.png")" "picture"
check "pictures reachable through the site" "$(cat "$P/output/media/my-art/a.png")" "picture"
check "old pages kept aside" "$([ -f "$P/output-before-ram/similar/0001-01.html" ] && echo yes)" "yes"
check "old site no longer holds the pictures" "$([ -e "$P/output-before-ram/media" ] && echo yes || echo no)" "no"
# }}}

# {{{ running again changes nothing
"$DIR/scripts/ensure-site-in-ram" "$P" >/dev/null 2>&1
check "second run: exits cleanly" "$?" "0"
check "second run: link unchanged" "$(readlink "$P/output")" "tmp/shared-memory/site"
# }}}

# {{{ a simulated logout empties RAM; the next run rebuilds the layout
mkdir -p "$P/output/similar"
echo '<html><pre>page</pre></html>' > "$P/output/similar/0002-01.html"
rm -rf "$P/tmp/shared-memory/site"
check "after logout: site link is dangling" "$([ -L "$P/output" ] && [ ! -e "$P/output" ] && echo yes)" "yes"
"$DIR/scripts/ensure-site-in-ram" "$P" >/dev/null 2>&1
check "after logout: rerun exits cleanly" "$?" "0"
check "after logout: site folder exists again" "$([ -d "$P/output/" ] && echo yes)" "yes"
check "after logout: pages are gone (rebuild needed)" "$([ -e "$P/output/similar/0002-01.html" ] && echo yes || echo no)" "no"
check "after logout: pictures still there" "$(cat "$P/output/media/my-art/a.png")" "picture"
# }}}

# {{{ the page check goes through the linked site folder
mkdir -p "$P/output/similar"
echo '<html><pre>fine</pre></html>' > "$P/output/similar/0003-01.html"
out=$("$DIR/scripts/validate-output" "$DIR" --jobs 1 --output "$P/output" --report "$SCRATCH/report.txt" 2>&1)
check "page check passes the linked site" "$?" "0"
check "page check counted the page" "$(printf '%s' "$out" | grep -c '^Checking 1 pages')" "1"
# }}}

# {{{ deploy refuses a missing or empty site before contacting the live site
# A missing site diffed against the live one reads as "everything is stale",
# and --prune would delete the live site. The checks run before any network
# call, so --dry-run here never reaches the server.
D="$SCRATCH/deploy"
mkdir -p "$D"
ln -s "$DIR/libs" "$D/libs"
ln -s tmp/shared-memory/site "$D/output"
out=$(luajit "$DIR/scripts/deploy-to-neocities" "$D" --dry-run 2>&1)
check "deploy: missing site refused" "$(printf '%s' "$out" | grep -c 'there is no built site')" "1"
mkdir -p "$D/tmp/shared-memory/site"
out=$(luajit "$DIR/scripts/deploy-to-neocities" "$D" --dry-run 2>&1)
check "deploy: empty site refused" "$(printf '%s' "$out" | grep -c 'holds no files')" "1"
# }}}

# {{{ the helper refuses when the RAM tier is missing
Q="$SCRATCH/no-shm"
mkdir -p "$Q"
"$DIR/scripts/ensure-site-in-ram" "$Q" >/dev/null 2>&1
check "missing tmp/shared-memory: refused" "$?" "1"
# }}}

rm -rf "$SCRATCH"
echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
