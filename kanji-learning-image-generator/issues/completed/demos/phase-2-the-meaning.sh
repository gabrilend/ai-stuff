#!/usr/bin/env bash
#
# phase-2-the-meaning -- a character becomes a world, a cast, and a sentence
#
# Shows the reasoning rather than describing it: which world each character
# landed in and what the runner-up was, which of its pieces became subjects and
# which were demoted for being there only for their sound, what object every
# named stroke is carrying, and the finished sentence. Then the same reasoning
# across the whole archive, and real fields and arrows to look at -- because in
# this phase, looking is the test.

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/kanji-learning-image-generator"
if [ -n "$1" ] && [ -d "$1" ]; then DIR="$1"; shift; fi
# }}}

set -u
SHOW="${DIR}/tmp/shared-memory/demo-phase-2"

if [ ! -f "${DIR}/assets/kanjivg.xml" ]; then
  echo "The archives are not in assets/ yet. Get them with:"
  echo "    luajit ${DIR}/src/010-fetch-the-archives.lua"
  exit 1
fi

mkdir -p "$SHOW"

echo
echo "=============================================================="
echo " PHASE TWO -- THE MEANING"
echo " a character becomes a world, a cast, and a sentence"
echo "=============================================================="
echo
echo "-- the stroke classes, measured off the archive --------------"
echo
luajit "${DIR}/src/021-the-shape-of-a-stroke.lua" --dir "$DIR" --calibrate \
  | head -14

echo
echo "-- what the pieces of a character are taken to depict --------"
echo
luajit "${DIR}/src/023-the-component-lexicon.lua" --dir "$DIR" --chars "休語時"

echo
echo "-- how much of the archive can be pictured at all ------------"
echo
luajit "${DIR}/src/023-the-component-lexicon.lua" --dir "$DIR" --coverage \
  | head -10

echo
echo "-- the whole reasoning, for four characters ------------------"
luajit "${DIR}/src/024-the-scene-grammar.lua" --dir "$DIR" --chars "休語時川"

echo
echo "-- and the sentences that come out of it ---------------------"
luajit "${DIR}/src/025-the-words-the-machine-reads.lua" --dir "$DIR" \
       --chars "休語時川" | head -14

echo
echo "-- which world every character in the archive landed in ------"
echo
luajit "${DIR}/src/024-the-scene-grammar.lua" --dir "$DIR" --spread

echo
echo "-- fields and arrows, to look at -----------------------------"
echo
luajit "${DIR}/src/026-arrows-that-teach-the-order.lua" --dir "$DIR" \
       --chars "一川休森語鬱" --out "$SHOW"

if command -v magick >/dev/null 2>&1; then
  for c in 一 川 休 森 語 鬱; do
    magick "$SHOW/$c-field.png" -colorspace sRGB -type TrueColor \
           "$SHOW/$c-arrows.png" -composite "$SHOW/$c-card.png" 2>/dev/null
  done
  magick "$SHOW"/一-card.png "$SHOW"/川-card.png "$SHOW"/休-card.png \
         "$SHOW"/森-card.png "$SHOW"/語-card.png "$SHOW"/鬱-card.png \
         +append -resize 1200x200 "$SHOW/all-large.png" 2>/dev/null
  magick "$SHOW"/一-card.png "$SHOW"/川-card.png "$SHOW"/休-card.png \
         "$SHOW"/森-card.png "$SHOW"/語-card.png "$SHOW"/鬱-card.png \
         +append -resize 480x80 "$SHOW/all-thumbnail.png" 2>/dev/null
  echo "  six characters side by side:"
  echo "    $SHOW/all-large.png      -- at the size it is meant to fail at"
  echo "    $SHOW/all-thumbnail.png  -- at the size it is meant to work at"
  echo
  echo "  That second one is the whole specification of this project. Look at it."
else
  echo "  (ImageMagick is not here, so the pictures were not stacked side by side)"
fi
echo
echo "the pictures are in $SHOW"
echo
