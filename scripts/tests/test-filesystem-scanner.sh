#!/usr/bin/env bash
# test-filesystem-scanner.sh -- checks filesystem_scanner.sh: scanning, the
# --day/--at schedule options, the cron commands, and the -I menu (issue
# 014, phase 1).
#
# Nothing real is touched. The scripts folder is a scratch one (SCRIPTS_DIR)
# whose RAM tier is built under the scratch folder too (EXEC_TIER_ROOT and
# ARTIFACT_TIER_ROOT), and the crontab is a stand-in script that keeps its
# "crontab" in a scratch file (FILESYSTEM_SCANNER_CRONTAB).
#
# The menu is driven in a pretend terminal (`script`, 46x100 so the cron
# panel has room below the items; keys typed one second apart). Its items,
# top to bottom, with two folders offered:
#    1 Scan now   2 Install cron job   3 Remove cron job   4 Preview schedule
#    5 first folder   6 second folder   7 Another folder...
#    8 Every day   9-15 Sunday..Saturday   16 Hour   17 Minute   18 Go
# G jumps to Go.
#
# Needs `script` (util-linux) and luajit. Takes about two minutes.
# Usage: bash scripts/tests/test-filesystem-scanner.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
SCANNER="$DIR/filesystem_scanner.sh"
SCANNER_REAL="$(realpath "$SCANNER")"
WORK="$(mktemp -d /tmp/test-filesystem-scanner-XXXXXX)"

# {{{ scratch scripts folder, RAM tier and crontab
mkdir -p "$WORK/scripts" "$WORK/exec" "$WORK/shm" "$WORK/bin"
ln -s "$DIR/libs" "$WORK/scripts/libs"
export SCRIPTS_DIR="$WORK/scripts"
export EXEC_TIER_ROOT="$WORK/exec"
export ARTIFACT_TIER_ROOT="$WORK/shm"
ARTIFACTS="$WORK/shm/scripts/filesystem-scanner"
CRONTAB_FILE="$WORK/crontab.txt"
cat > "$WORK/bin/crontab" <<EOF
#!/usr/bin/env bash
# stand-in crontab: -l prints the scratch file, a file argument replaces it
if [ "\$1" = "-l" ]; then
    [ -f "$CRONTAB_FILE" ] || { echo "no crontab for test" >&2; exit 1; }
    cat "$CRONTAB_FILE"
else
    cp "\$1" "$CRONTAB_FILE"
fi
EOF
chmod +x "$WORK/bin/crontab"
export FILESYSTEM_SCANNER_CRONTAB="$WORK/bin/crontab"
# }}}

# {{{ folders to scan
for t in a b c; do
    mkdir -p "$WORK/tree-$t/sub"
    echo "hello" > "$WORK/tree-$t/file-$t.txt"
    echo "x" > "$WORK/tree-$t/sub/deep-$t.txt"
done
# }}}

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# {{{ helpers
picture_of() { echo "$ARTIFACTS/$(realpath "$1" | sed 's|^/||; s|/|-|g')-hierarchy.txt"; }
cron_line() { grep -F "$SCANNER_REAL" "$CRONTAB_FILE" 2>/dev/null; }
# drive <name> <folder> <keys...>: the menu on <folder>, keys, then q
drive() {
    local name="$1" folder="$2"; shift 2
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        printf 'q'; sleep 1
    } | timeout 90 script -qfc "stty rows 46 cols 100; bash $SCANNER -I $folder" "$WORK/$name.log" >/dev/null 2>&1
}
screen() { luajit "$DIR/libs/test-menu-screen-replay.lua" "$WORK/$1.log" 46 100; }
# only tree-b is remembered, so the menu offers the named folder, then tree-b
recent_only_b() { mkdir -p "$ARTIFACTS"; realpath "$WORK/tree-b" > "$ARTIFACTS/recent-folders.txt"; }
# }}}

# {{{ scanning from the command line
bash "$SCANNER" "$WORK/tree-a" > /dev/null 2>&1
check "a scan writes the picture into the RAM tier" "$([ -s "$(picture_of "$WORK/tree-a")" ] && echo yes || echo no)" "yes"
check "the picture lists a file in a subfolder" "$(grep -c 'deep-a.txt' "$(picture_of "$WORK/tree-a")")" "1"
check "nothing is written into the scanned folder" "$(find "$WORK/tree-a" -type f | wc -l)" "2"
check "the folder is remembered" "$(cat "$ARTIFACTS/recent-folders.txt")" "$(realpath "$WORK/tree-a")"
bash "$SCANNER" "$WORK/tree-b" > /dev/null 2>&1
bash "$SCANNER" "$WORK/tree-a" > /dev/null 2>&1
check "the latest scan comes first, each folder once" \
    "$(tr '\n' ' ' < "$ARTIFACTS/recent-folders.txt")" "$(realpath "$WORK/tree-a") $(realpath "$WORK/tree-b") "
# }}}

# {{{ --day and --at, and the cron commands
bash "$SCANNER" --install-cron "$WORK/tree-a" --day wed --at 23:30 > /dev/null 2>&1
check "install writes the chosen schedule" "$(cron_line | cut -d' ' -f1-5)" "30 23 * * 3"
check "and the folder" "$(cron_line | grep -c "\"$WORK/tree-a\"")" "1"
check "show-cron reads it out" \
    "$(bash "$SCANNER" --show-cron "$WORK/tree-a" --day wed --at 23:30 | grep -c 'Every Wednesday at 11:30 PM')" "1"
bash "$SCANNER" --install-cron "$WORK/tree-a" --day daily --at 4:05 > /dev/null 2>&1
check "installing again replaces the line" "$(cron_line | wc -l)" "1"
check "daily is every day" "$(cron_line | cut -d' ' -f1-5)" "5 4 * * *"
check "a bad day is refused" "$(bash "$SCANNER" --install-cron "$WORK/tree-a" --day someday >/dev/null 2>&1; echo $?)" "1"
check "a bad time is refused" "$(bash "$SCANNER" --install-cron "$WORK/tree-a" --at 25:00 >/dev/null 2>&1; echo $?)" "1"
check "and the crontab is left as it was" "$(cron_line | cut -d' ' -f1-5)" "5 4 * * *"
bash "$SCANNER" --uninstall-cron > /dev/null 2>&1
check "uninstall removes it" "$(cron_line | wc -l)" "0"
# }}}

# {{{ the menu: scan the named folder
recent_only_b
rm -f "$(picture_of "$WORK/tree-a")"
drive scan "$WORK/tree-a" G $'\r'
check "Go with Scan now scans the named folder" "$([ -s "$(picture_of "$WORK/tree-a")" ] && echo yes || echo no)" "yes"
check "the menu comes back and says so" "$(screen scan | grep -c 'Scanned')" "1"
check "the menu shows the cron status" "$(screen scan | grep -c 'No cron job installed')" "1"
# }}}

# {{{ the menu: scan a remembered folder
recent_only_b
rm -f "$(picture_of "$WORK/tree-b")"
drive recent "$WORK/tree-a" j j j j j ' ' G $'\r'
check "choosing the remembered folder scans it" "$([ -s "$(picture_of "$WORK/tree-b")" ] && echo yes || echo no)" "yes"
# }}}

# {{{ the menu: another folder, typed
recent_only_b
drive other "$WORK/tree-a" j j j j j j ' ' G $'\r' "$WORK/tree-c"$'\r'
check "a typed folder is scanned" "$([ -s "$(picture_of "$WORK/tree-c")" ] && echo yes || echo no)" "yes"
# }}}

# {{{ the menu: install on Friday at 7, then remove
recent_only_b
drive install "$WORK/tree-a" j ' ' j j j j j j j j j j j j ' ' j j 7 G $'\r'
check "install from the menu uses the chosen day and hour" "$(cron_line | cut -d' ' -f1-5)" "0 7 * * 5"
check "and the named folder" "$(cron_line | grep -c "\"$(realpath "$WORK/tree-a")\"")" "1"
check "the menu says so" "$(screen install | grep -c 'Cron job installed: Every Friday at 7:00 AM')" "1"
check "and shows the installed line" "$(screen install | grep -c '0 7 \* \* 5')" "1"

recent_only_b
drive badtime "$WORK/tree-a" j ' ' G k k 9 9 G $'\r'
check "an hour of 99 is refused" "$(screen badtime | grep -c 'Not done: the hour must be 0-23')" "1"
check "and the crontab is unchanged" "$(cron_line | cut -d' ' -f1-5)" "0 7 * * 5"

recent_only_b
drive remove "$WORK/tree-a" j j ' ' G $'\r'
check "remove from the menu takes the job out" "$(cron_line | wc -l)" "0"
check "the menu says so" "$(screen remove | grep -c 'Cron job removed')" "1"
# }}}

rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
