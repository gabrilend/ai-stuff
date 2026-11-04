#!/usr/bin/env bash
# build-download-zip.test.sh -- the download comes in pieces Neocities takes (Issue 10-077).
# Run: bash scripts/build-download-zip.test.sh [--dir PATH]
#
# What it checks (for a CEO): the "download everything" archive is cut into
# pieces no bigger than 92,159 KiB, because Neocities refuses any file over 100 MB
# (a single 2.37 GB archive stopped the 2026-11-02 deploy). The pieces join
# back into an archive that opens cleanly and holds what went in; a page lists
# every piece once; the archive does not pack its own earlier pieces; and the
# builder refuses a stray word on its command line.
#
# How: a small scratch project in RAM (tmp/shared-memory/), with git, two
# source files, a copy of config.lua (for the site's colours) and a 200 MB
# file of random bytes in its site -- random so it cannot compress below
# three pieces. The real builder runs against it with --dir.

# --help: print the header above and exit, before any work (libs/script-help.sh)
source "$(dirname "$(readlink -f "$0")")/../libs/script-help.sh"
script_help "$0" "$@"

set -u
# The project folder: --dir PATH, or the path below; a stray word on the
# command line stops the script (libs/project-dir.sh, Issue 10-076).
source "$(dirname "$(readlink -f "$0")")/../libs/project-dir.sh"
project_dir_read "/mnt/mtwo/programming/ai-stuff/neocities-modernization" "" "$@"

"${DIR}/scripts/ensure-tmp-symlink" --dir "${DIR}" >/dev/null || {
    echo "FATAL: could not materialize tmp/ -- cannot test"; exit 2
}

pass=0; fail=0
# {{{ check
# check <label> <condition-exit-status> [detail]
check() {
    if [ "$2" = "0" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1${3:+: $3}"; fi
}
# }}}

# {{{ the scratch project
SCRATCH="${DIR}/tmp/shared-memory/build-download-zip-test"
# The scratch project's own RAM tiers are made by ensure-tmp-symlink, named
# after the folder (/tmp/NAME, /dev/shm/NAME), so the name is one nothing
# else uses; both are removed at the end.
PROJECT_NAME="neocities-download-zip-test"
PROJECT="${SCRATCH}/${PROJECT_NAME}"
rm -rf "$SCRATCH" "/tmp/${PROJECT_NAME}" "/dev/shm/${PROJECT_NAME}"
# removed however the test ends (a pass, a failure, or the 7-Zip skip): it
# holds about 600 MB of RAM
trap 'rm -rf "$SCRATCH" "/tmp/${PROJECT_NAME}" "/dev/shm/${PROJECT_NAME}"' EXIT
mkdir -p "$PROJECT/src" "$PROJECT/output"
"${DIR}/scripts/ensure-tmp-symlink" --dir "$PROJECT" >/dev/null || {
    echo "FATAL: could not make the scratch project's tmp/"; exit 2
}
# the builder reads its helpers and the site's colours from the project it is
# given; the real ones are linked in (not committed, so not packed)
ln -s "${DIR}/scripts" "$PROJECT/scripts"
mkdir -p "$PROJECT/libs"
for lib in "${DIR}"/libs/*.lua; do ln -s "$lib" "$PROJECT/libs/"; done
ln -s "${DIR}/src/page-theme.lua" "$PROJECT/src/page-theme.lua"
cp "${DIR}/config.lua" "$PROJECT/config.lua"
echo 'print("a source file")' > "$PROJECT/src/a.lua"
echo '# notes' > "$PROJECT/readme.md"
git -C "$PROJECT" init -q
git -C "$PROJECT" add src/a.lua readme.md
git -C "$PROJECT" -c user.name=test -c user.email=test@example.invalid commit -q -m "test project"
head -c 209715200 /dev/urandom > "$PROJECT/output/big.bin"
echo '<p>a page</p>' > "$PROJECT/output/wordcloud.html"
# an earlier build's leftovers, which must not be packed or survive
mkdir -p "$PROJECT/output/download"
echo "old piece" > "$PROJECT/output/download/similar-different.z99"
echo "old whole archive" > "$PROJECT/tmp/shared-memory/similar-different.zip"
ln -s "$PROJECT/tmp/shared-memory/similar-different.zip" "$PROJECT/output/similar-different.zip"
# }}}

# {{{ a stray word is refused
out=$("${DIR}/scripts/build-download-zip" "$PROJECT" 2>&1)
status=$?
{ [ "$status" = "1" ] && printf '%s' "$out" | grep -q "unexpected word"; }
check "a bare word stops the builder" $? "status $status: $out"
# }}}

# {{{ the real build
out=$("${DIR}/scripts/build-download-zip" --dir "$PROJECT" 2>&1)
status=$?
check "the builder finishes" "$status" "$out"
D="$PROJECT/output/download"

[ -f "$D/similar-different.z01" ] && [ -f "$D/similar-different.z02" ] && [ -f "$D/similar-different.zip" ] && [ ! -e "$D/similar-different.z03" ]
check "200 MB of random bytes makes three pieces (.z01, .z02, .zip)" $? "$(ls "$D")"

over=0
for piece in "$D"/similar-different.z*; do
    [ "$(stat -c %s "$piece")" -le 94370816 ] || over=1
done
[ "$over" = "0" ]; check "no piece is over 92,159 KiB (94,370,816 bytes)" $?

[ ! -e "$D/similar-different.z99" ]; check "the previous build's pieces are gone" $?
[ ! -e "$PROJECT/output/similar-different.zip" ] && [ ! -e "$PROJECT/tmp/shared-memory/similar-different.zip" ]
check "the old single archive and its link are gone" $?
[ ! -e "$PROJECT/tmp/shared-memory/similar-different.zip.building" ]
check "the whole archive is not left behind in RAM" $?

links_ok=0
for piece in similar-different.z01 similar-different.z02 similar-different.zip; do
    [ "$(grep -c "href=\"${piece}\"" "$D/index.html")" = "1" ] || links_ok=1
done
check "the page links each piece exactly once" "$links_ok" "$(grep href "$D/index.html")"
grep -q "you need all 3 files" "$D/index.html"
check "the page says how many pieces there are" $?
grep -q 'bgcolor="#' "$D/index.html"
check "the page opens with the site's colours" $?
# }}}

# {{{ the pieces join with zip and open with unzip, as the page says first
# The page's first way, on nearly every machine: zip -s 0 joins the pieces,
# unzip opens the result. Info-ZIP zip 3.0's join drops every byte after the
# second piece of a file when a piece is a whole number of its 16,384-byte
# copy buffers (exactly 90 MiB was 5,760 of them, 2026-11-03). The 200 MB
# file here spans all three pieces, a whole middle piece included -- the case
# that lost data -- so this fails if the piece size ever divides evenly again.
JOINED="${SCRATCH}/joined.zip"
zip -q -s 0 "$D/similar-different.zip" --out "$JOINED"
check "zip -s 0 joins the pieces into one archive" $?
UNZIPPED="${SCRATCH}/unzipped"
unzip -q -o "$JOINED" -d "$UNZIPPED" 2>/dev/null
check "unzip opens the joined archive" $?
[ "$(md5sum < "$UNZIPPED/output/big.bin")" = "$(md5sum < "$PROJECT/output/big.bin")" ]
check "zip and unzip bring the big file back byte for byte" $?
# }}}

# {{{ the pieces open with 7-Zip, the page's second way
if ! command -v 7z >/dev/null; then
    echo "SKIP: 7z is not installed, so the pieces cannot be opened the page's second way"
    exit 0
fi
tested=$(7z t "$D/similar-different.zip" 2>&1)
printf '%s' "$tested" | grep -q "Everything is Ok"
check "7-Zip tests the pieces clean" $? "$(printf '%s' "$tested" | tail -5)"
OPENED="${SCRATCH}/opened"
7z x -y -o"$OPENED" "$D/similar-different.zip" >/dev/null
check "7-Zip opens the pieces" $?
[ "$(md5sum < "$OPENED/output/big.bin")" = "$(md5sum < "$PROJECT/output/big.bin")" ]
check "the site's big file comes out byte for byte" $?
[ -f "$OPENED/src/a.lua" ]; check "it holds the committed source" $?
[ ! -e "$OPENED/output/download" ]; check "it does not pack its own download folder" $?
[ -f "$OPENED/readme.txt" ]; check "it carries the readme" $?
# }}}

echo
echo "${pass} passed, ${fail} failed"
[ "$fail" = "0" ]
