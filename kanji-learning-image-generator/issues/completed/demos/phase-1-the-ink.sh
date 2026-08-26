#!/usr/bin/env bash
#
# phase-1-the-ink -- two archives become geometry, and geometry becomes pixels
#
# Shows the data actually being read: how long thirty megabytes of XML takes,
# what joined and what fell out of the join and why, every stroke in the archive
# parsed and flattened, and a character drawn to a real picture file with what
# the compressor achieved on it. Nothing here knows what a kanji means.

# {{{ DIR -- the project root, hard-coded, overridable by an argument
DIR="/mnt/mtwo/programming/ai-stuff/kanji-learning-image-generator"
if [ -n "$1" ] && [ -d "$1" ]; then DIR="$1"; shift; fi
# }}}

set -u
SHOW="${DIR}/tmp/shared-memory/demo-phase-1"

if [ ! -f "${DIR}/assets/kanjivg.xml" ] || [ ! -f "${DIR}/assets/kanjidic2.xml" ]; then
  echo "The two archives are not in assets/ yet. Get them with:"
  echo "    luajit ${DIR}/src/010-fetch-the-archives.lua"
  exit 1
fi

mkdir -p "$SHOW"

echo
echo "=============================================================="
echo " PHASE ONE -- THE INK"
echo " two archives become geometry, and geometry becomes pixels"
echo "=============================================================="
echo
echo "-- what the archives hold, and what the join threw away ------"
echo
luajit "${DIR}/src/019-the-kanji-record.lua" --dir "$DIR" --rebuild --report | head -22

echo
echo "-- every stroke in the archive, parsed and flattened ---------"
echo
luajit "${DIR}/src/020-test-the-ink.lua" --dir "$DIR"

echo
echo "-- a character drawn to a real picture file ------------------"
echo
luajit "${DIR}/src/022-the-structure-field.lua" --dir "$DIR" \
       --chars "一川休森語鬱" --out "$SHOW"

echo
echo "-- what the compressor achieved ------------------------------"
echo
printf "  %-10s %10s %10s %8s\n" "file" "raw bytes" "on disk" "share"
for f in "$SHOW"/*.png; do
  case "$f" in *-thumb.png) continue;; esac
  name=$(basename "$f" .png)
  on_disk=$(stat -c %s "$f")
  raw=$(( 768 * 768 ))
  share=$(awk -v a="$on_disk" -v b="$raw" 'BEGIN{printf "%.1f%%", a/b*100}')
  printf "  %-10s %10d %10d %8s\n" "$name" "$raw" "$on_disk" "$share"
done

echo
echo "  Uncompressed blocks are legal in this format and would have put every"
echo "  one of those at a hundred percent."
echo
echo "the pictures are in $SHOW"
echo
