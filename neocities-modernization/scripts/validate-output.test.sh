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

# {{{ frame shapes: the real pieces pass, a short bar and a moved junction fail
# The real pieces come from src/poem-bars.lua, which draws the site's frames,
# so this test follows the frames if their geometry ever changes.
SHAPES="$SCRATCH/shapes"
mkdir -p "$SHAPES/similar"  # poem folder: frame shapes are checked there
REAL=$(luajit -e "
    package.path = '$DIR/src/?.lua;' .. package.path
    local B = require('poem-bars')
    local s, d, c = '<a>similar</a>', '<a>different</a>', '<a>chronological</a>'
    for _, golden in ipairs({ false, true }) do
        print(B.progress_dashes({ percentage = 40 }, 'gray', golden, 'top').visual)
        print(B.progress_dashes({ percentage = 40 }, 'gray', golden, 'bottom', true).visual)
    end
    print(B.corner_box_top(30, '#fff'))
    print(B.corner_box_nav_line(s, d, c, 30, '#fff'))
    print(B.corner_box_bottom())
    print(B.golden_corner_box_separator('#fff', 30))
    print(B.golden_corner_box_nav_line(s, d, c, '#fff', 30))
")
{ echo '<html><pre>'; printf '%s\n' "$REAL"; echo '</pre></html>'; } > "$SHAPES/similar/real.html"
"$DIR/scripts/validate-output" "$DIR" --output "$SHAPES" --report "$SCRATCH/shapes-real.txt" >/dev/null 2>&1
check "every real frame piece passes" "$?" "0"

SHORT=$(printf '═%.0s' $(seq 1 82))
# 83 wide, as a bottom line must be, but its left junction at column 11, not 10:
# ╘ + 10 ═ + ╧ + 58 ═ + ┴ (column 70) + 11 ─ + ┘
MOVED="╘$(printf '═%.0s' $(seq 1 10))╧$(printf '═%.0s' $(seq 1 58))┴$(printf '─%.0s' $(seq 1 11))┘"
{ echo '<html><pre>'; echo "$SHORT"; echo "$MOVED"; echo '</pre></html>'; } > "$SHAPES/similar/bad.html"
"$DIR/scripts/validate-output" "$DIR" --output "$SHAPES" --report "$SCRATCH/shapes-bad.txt" >/dev/null 2>&1
check "misshapen pieces: fails" "$?" "1"
check "counts two misshapen pieces" \
    "$(grep -c 'with a junction out of place: 2$' "$SCRATCH/shapes-bad.txt")" "1"
check "the 82-wide bar is named" "$(grep -c '82 wide, must be 83' "$SCRATCH/shapes-bad.txt")" "1"
check "the moved junction is named" "$(grep -c 'no junction at column 10' "$SCRATCH/shapes-bad.txt")" "1"
# }}}

# {{{ pages that show no poems are held only to their links
# The gallery draws its own 78-column rules and the source browser quotes code
# and old broken examples; neither is a poem frame.
OTHER="$SCRATCH/other"
mkdir -p "$OTHER/gallery" "$OTHER/source"
RULE=$(printf '─%.0s' $(seq 1 78))
printf '<html><pre>\n%s\n%s\n</pre></html>\n' "$RULE" "$LONG$LONG" > "$OTHER/gallery/index.html"
printf '<html><pre>\n%s\n</pre></html>\n' "$SHORT" > "$OTHER/source/quoted.html"
"$DIR/scripts/validate-output" "$DIR" --output "$OTHER" --report "$SCRATCH/other.txt" >/dev/null 2>&1
check "gallery rule, long line and quoted short bar outside poem folders: pass" "$?" "0"
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
