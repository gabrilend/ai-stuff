#!/usr/bin/env bash
# validate-output.test.sh (Issue 9-006) -- proves the whole-site checker
# catches an over-wide line and a broken link, files each under the right
# cause, and passes a clean site.  Builds two tiny handmade sites in RAM.
# Run: bash scripts/validate-output.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
"$DIR/scripts/ensure-tmp-symlink" "$DIR" >/dev/null
SCRATCH="$DIR/tmp/shared-memory/validate-output-test"
rm -rf "$SCRATCH"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ a site with one of each problem
SITE="$SCRATCH/broken"
mkdir -p "$SITE/similar" "$SITE/chronological"
BAR=$(printf '═%.0s' $(seq 1 83))                 # a regular 83-wide bar: fine
LONG=$(printf 'x%.0s' $(seq 1 90))
{
    echo '<html><body><pre>'
    echo "$BAR"
    echo " │ CW: $LONG │"                           # 99 wide: a warning box
    echo 'see https://example.com/'"$LONG"         # 114 wide: a web address
    echo '<a href="../chronological/01.html#poem-1">chrono</a> <a href="0001-02.html">next</a>'
    echo 'café &amp; crème &#39;quoted&#39;'          # accents and entities: short
    echo '</pre></body></html>'
} > "$SITE/similar/0001-01.html"
echo '<html><pre>fine</pre></html>' > "$SITE/chronological/01.html"

out=$("$DIR/scripts/validate-output" "$DIR" --output "$SITE" --report "$SCRATCH/broken.txt" 2>&1)
check "broken site: fails" "$?" "1"
check "counts two over-wide lines" "$(grep -c '^Over-wide lines: 2$' "$SCRATCH/broken.txt")" "1"
check "the warning box is filed under cw" "$(grep -cE '^  cw +1 lines, widest 99$' "$SCRATCH/broken.txt")" "1"
check "the address is filed under url" "$(grep -cE '^  url +1 lines' "$SCRATCH/broken.txt")" "1"
check "the 83-wide bar is not reported" "$(grep -c '\[bar\]' "$SCRATCH/broken.txt")" "0"
check "counts one broken link" "$(grep -c '^Broken links: 1$' "$SCRATCH/broken.txt")" "1"
check "names the missing page" "$(grep -c '0001-02.html' "$SCRATCH/broken.txt")" "2"
check "a link that resolves through .. is not reported" "$(grep -c 'chronological/01.html' "$SCRATCH/broken.txt")" "0"
# }}}

# {{{ a clean site passes
CLEAN="$SCRATCH/clean"
mkdir -p "$CLEAN"
printf '<html><pre>\n%s\nshort line\n</pre><a href="index.html">home</a></html>\n' "$BAR" > "$CLEAN/index.html"
"$DIR/scripts/validate-output" "$DIR" --output "$CLEAN" --report "$SCRATCH/clean.txt" >/dev/null 2>&1
check "clean site: passes" "$?" "0"
# }}}

# {{{ a missing site is refused
"$DIR/scripts/validate-output" "$DIR" --output "$SCRATCH/nowhere" >/dev/null 2>&1
check "missing site: refused" "$?" "1"
# }}}

rm -rf "$SCRATCH"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
