#!/usr/bin/env bash
# validate-poem-representation.test.sh -- the coverage checker notices a poem
# the site left out.
#
# Builds a three-poem site in RAM (each poem's first similar and different
# page, a chronological page anchoring each poem by its source key, and the
# redirect), checks it passes, then takes pieces away one at a time and checks
# each is reported: a missing similar page, a missing different page, a poem
# on no chronological page, a missing redirect. This is what the whole-site
# check (scripts/validate-output) cannot see -- a page that was never written
# has no broken line and, if nothing links to it, no broken link.
#
# Usage:  scripts/validate-poem-representation.test.sh [DIR]
DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
TOOL="$DIR/scripts/validate-poem-representation"
S="$DIR/tmp/shared-memory/validate-poem-representation-test"
passed=0
failed=0
# {{{ check
check() {
    if [ "$2" = "$3" ]; then passed=$((passed + 1)); echo "  ok   $1"
    else failed=$((failed + 1)); echo "  FAIL $1 -- got [$2] want [$3]"; fi
}
# }}}
# {{{ build: a complete three-poem site
build() {
    rm -rf "$S"
    mkdir -p "$S/site/similar" "$S/site/different" "$S/site/chronological"
    cat > "$S/poems.json" <<'JSON'
{"poems":[{"poem_index":1,"source_key":"notes-1"},{"poem_index":2,"source_key":"notes-2"},{"poem_index":3,"source_key":"fediverse-9"}]}
JSON
    for k in notes-1 notes-2 fediverse-9; do
        echo "<html></html>" > "$S/site/similar/$k-01.html"
        echo "<html></html>" > "$S/site/different/$k-01.html"
    done
    printf '<pre><span id="notes-1"></span>\n<span id="notes-2"></span>\n<span id="fediverse-9"></span></pre>\n' > "$S/site/chronological/01.html"
    echo "<html></html>" > "$S/site/chronological/index.html"
}
# }}}
run() { "$TOOL" --output "$S/site" --poems "$S/poems.json" --quiet > "$S/out.txt" 2>&1; echo $?; }

build
check "a complete site passes" "$(run)" "0"

build; rm "$S/site/similar/notes-2-01.html"
check "a missing similar page fails" "$(run)" "1"
check "and is counted" "$(grep -c '1 poems missing from similar' "$S/out.txt")" "1"

build; rm "$S/site/different/fediverse-9-01.html"
check "a missing different page fails" "$(run)" "1"

build; printf '<pre><span id="notes-1"></span>\n<span id="fediverse-9"></span></pre>\n' > "$S/site/chronological/01.html"
check "a poem on no chronological page fails" "$(run)" "1"
check "and is named" "$(grep -c '1 poems on no chronological page' "$S/out.txt")" "1"

build; rm "$S/site/chronological/index.html"
check "a missing redirect fails" "$(run)" "1"

rm -rf "$S"
echo
echo "passed $passed, failed $failed"
[ "$failed" = 0 ]
