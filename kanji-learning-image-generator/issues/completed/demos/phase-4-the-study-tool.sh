#!/usr/bin/env bash
#
# phase-4-the-study-tool -- pictures kept, rated, filtered, and argued with
#
# Shows the studio: every piece of a character named as a learner is told to
# name it, a whole word as one picture, an argument that overrides a scene it
# disagrees with, the wall that refuses a bad argument, the pool with everything
# ever made in it, a machine that squints at a picture and says whether the
# character survived, the dial that says what raising quality costs before it
# costs it, and the animation a good picture earns.

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/kanji-learning-image-generator"
if [ -n "$1" ] && [ -d "$1" ]; then DIR="$1"; shift; fi
# }}}

set -u
SHOW="${DIR}/tmp/shared-memory/demo-phase-4"

if [ ! -f "${DIR}/assets/kanjivg.xml" ]; then
  echo "The archives are not in assets/ yet. Get them with:"
  echo "    luajit ${DIR}/src/010-fetch-the-archives.lua"
  exit 1
fi

rm -rf "$SHOW"
mkdir -p "$SHOW"

echo
echo "=============================================================="
echo " PHASE FOUR -- THE STUDY TOOL"
echo " pictures kept, rated, filtered, and argued with"
echo "=============================================================="
echo
echo "-- every piece under the name it bears ------------------------"
echo
echo "  The character for time is a sun over a temple, and the mnemonic"
echo "  works BECAUSE a temple has nothing to do with time."
echo
luajit "${DIR}/src/023-the-component-lexicon.lua" --dir "$DIR" --chars "時語休"

echo
echo "-- the same character, read the two ways ----------------------"
luajit "${DIR}/src/024-the-scene-grammar.lua" --dir "$DIR" --chars "時" \
  | grep -E "^時|world|reading|subject|ground"

echo
echo "-- a word is one picture -------------------------------------"
echo
luajit "${DIR}/src/019a-a-phrase-is-a-record-too.lua" --dir "$DIR" \
       --phrase "時間=time,an hour"

echo
echo "-- what a person may say about a picture ----------------------"
echo
luajit "${DIR}/src/024a-the-paintbrush.lua" --dir "$DIR" --contract \
  | sed -n '10,26p'

echo
echo "-- and what happens when they say something else --------------"
echo
cat > "${SHOW}/wrong.lua" <<'ARGEOF'
return {
  wold = "sky",
  world = "skies",
  reading = "mnemonik",
  subjects = { { "山", "a mountain" } },
  strokes = { [99] = "nowhere" },
  palette = 12,
}
ARGEOF
cp "${DIR}/input/arguments/時.lua" "${SHOW}/時-real.lua" 2>/dev/null || true
cp "${SHOW}/wrong.lua" "${DIR}/input/arguments/時.lua"
luajit "${DIR}/src/024a-the-paintbrush.lua" --dir "$DIR" --check 時 2>&1 | sed 's/^/  /'
if [ -f "${SHOW}/時-real.lua" ]; then
  cp "${SHOW}/時-real.lua" "${DIR}/input/arguments/時.lua"
else
  rm -f "${DIR}/input/arguments/時.lua"
fi

echo
echo "-- the machine that squints ----------------------------------"
echo
luajit "${DIR}/src/046-two-ways-of-saying-it-is-good.lua" --dir "$DIR" \
  | sed -n '1,16p'

echo
echo "-- everything ever made --------------------------------------"
echo
luajit "${DIR}/src/045-the-pool-that-remembers.lua" --dir "$DIR" | sed 's/^/  /'

echo
echo "-- what raising the quality would cost ------------------------"
echo
luajit "${DIR}/src/047-the-quality-dial.lua" --dir "$DIR" --floor 4 \
  | sed 's/^/  /'

echo
echo "-- what a good one earns -------------------------------------"
echo
luajit "${DIR}/src/048-what-a-higher-tier-buys.lua" --dir "$DIR" | sed 's/^/  /'

echo
echo "-- and whether there is a kitchen to cook in ------------------"
echo
bash "${DIR}/src/043-install-the-kitchen.sh" "$DIR" --check 2>&1 | sed 's/^/  /'

echo
echo "-------------------------------------------------------------"
echo "  Nothing above needed a graphics card. The pool fills with"
echo "  real pictures once one is running:"
echo
echo "    luajit ${DIR}/src/044-run-the-pictures.lua --grade 1"
echo "    luajit ${DIR}/src/032-a-gallery-you-can-page.lua --pool"
echo
