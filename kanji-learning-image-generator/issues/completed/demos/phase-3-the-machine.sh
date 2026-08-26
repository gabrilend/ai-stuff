#!/usr/bin/env bash
#
# phase-3-the-machine -- a whole set of characters, and two ways to look at it
#
# The product. Generates a complete set end to end in parallel, resting when the
# processor climbs, and prints the report -- how many were made, which worlds
# they landed in, which pieces still cannot be pictured. Then shows the shape of
# one workflow, builds the gallery, and builds this project's documentation as a
# website.

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/kanji-learning-image-generator"
if [ -n "$1" ] && [ -d "$1" ]; then DIR="$1"; shift; fi
# }}}

set -u
SHOW="${DIR}/tmp/shared-memory/demo-phase-3"
CHOICE="${1:---grade 1}"

if [ ! -f "${DIR}/assets/kanjivg.xml" ]; then
  echo "The archives are not in assets/ yet. Get them with:"
  echo "    luajit ${DIR}/src/010-fetch-the-archives.lua"
  exit 1
fi

rm -rf "$SHOW"
mkdir -p "$SHOW"

echo
echo "=============================================================="
echo " PHASE THREE -- THE MACHINE"
echo " a whole set of characters, and two ways to look at it"
echo "=============================================================="
echo
echo "-- what this machine will let a run do ------------------------"
echo
luajit "${DIR}/src/031a-when-the-machine-runs-hot.lua" --dir "$DIR"

echo
echo "-- generating a set ------------------------------------------"
echo
# shellcheck disable=SC2086
luajit "${DIR}/src/031-make-them-all.lua" --dir "$DIR" $CHOICE --out "$SHOW"

echo
echo "-- the shape of one recipe -----------------------------------"
echo
FIRST=$(ls -d "$SHOW"/*/ 2>/dev/null | head -1)
if [ -n "$FIRST" ]; then
  echo "  ${FIRST}"
  ls -la "$FIRST" | tail -n +4 | awk '{printf "    %-22s %8s bytes\n", $9, $5}'
  echo
  echo "  the nodes in its workflow, in the order they run:"
  grep -o '"class_type": "[^"]*"' "${FIRST}workflow.api.json" \
    | sed 's/"class_type": "//; s/"//' | nl -w6 -s'  '
  echo
  echo "  the sentence it will be drawn from:"
  grep -o '"positive": "[^"]*"' "${FIRST}card.json" \
    | sed 's/"positive": "//; s/"$//' | fold -s -w 66 | sed 's/^/    /'
fi

echo
echo "-- the gallery -----------------------------------------------"
echo
luajit "${DIR}/src/032-a-gallery-you-can-page.lua" --dir "$DIR" --set "$SHOW"

echo
echo "-- this project's own documentation, as a website -------------"
echo
luajit "${DIR}/src/033-the-documentation-site.lua" --dir "$DIR"

echo
echo "-------------------------------------------------------------"
echo "  the set        $SHOW"
echo "  the gallery    $SHOW/index.html"
echo "  the docs       ${DIR}/docs/HTML/index.html"
echo
echo "  Every folder in that set holds a recipe. Nothing here draws a"
echo "  picture -- a diffusion model does that, on a machine with a"
echo "  graphics card in it, from the two files and the two pictures"
echo "  each folder contains."
echo
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xdg-open >/dev/null 2>&1; then
  echo "  opening the gallery..."
  xdg-open "$SHOW/index.html" >/dev/null 2>&1 &
else
  echo "  (no display here, so nothing was opened for you)"
fi
echo
