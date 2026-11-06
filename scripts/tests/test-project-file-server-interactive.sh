#!/usr/bin/env bash
# test-project-file-server-interactive.sh -- checks project-file-server's -I
# menu (issue 014, phase 5): generating the page for the chosen folder,
# moving into a subfolder, a page written elsewhere, opening the page,
# serving it on this machine until Ctrl+C, and the tree preview.
#
# Nothing outside a scratch folder is touched. The folder scanned is a small
# tree made here; TMPDIR points into the scratch folder, so the menu's
# preview files land there (and the test checks they are cleaned up); the
# desktop opener is a stand-in xdg-open that only writes down what it was
# given. Serving starts python3's http.server on a random high port bound to
# 127.0.0.1, and stops it with Ctrl+C.
#
# The menu is driven in a pretend terminal (`script`, 60x100 so the preview
# has room below the items; keys typed one second apart). Its items, top to
# bottom, opened on site/:
#    1 Generate the page   2 Serve the page over HTTP   3 Open the page
#    4 Go into the folder
#    5 site (current)   6 ../ (parent)   7 ./alpha   8 ./beta   9 Another folder...
#   10 Inside the scanned folder   11 Another file...   12 Port   13 Go
# G jumps to Go. The menu reopens with the cursor on item 1.
#
# Needs `script` (util-linux), luajit and python3. Takes about two minutes.
# Usage: bash scripts/tests/test-project-file-server-interactive.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
RUNNER="$DIR/project-file-server"
WORK="$(mktemp -d /tmp/test-project-file-server-menu-XXXXXX)"

# {{{ the folder to scan, the scratch TMPDIR and the stand-in opener
mkdir -p "$WORK/site/alpha/deeper" "$WORK/site/beta" "$WORK/site/.git" \
         "$WORK/tmp" "$WORK/bin" "$WORK/pages"
echo "a" > "$WORK/site/alpha/a.txt"
echo "d" > "$WORK/site/alpha/deeper/d.txt"
echo "b" > "$WORK/site/beta/b.txt"
echo "x" > "$WORK/site/.git/config"
echo "# site" > "$WORK/site/readme.md"
export TMPDIR="$WORK/tmp"
cat > "$WORK/bin/xdg-open" <<EOF
#!/usr/bin/env bash
# stand-in opener: writes down the address it was asked to open
printf '%s\n' "\$1" >> "$WORK/opened.txt"
EOF
chmod +x "$WORK/bin/xdg-open"
PORT=$((20000 + RANDOM % 20000))
# }}}

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# {{{ helpers
# drive <name> <folder> <keys...>: the menu on <folder>, keys, then q. A key
# of WAIT types nothing (one more second's pause).
drive() {
    local name="$1" folder="$2"; shift 2
    {
        sleep 2
        for key in "$@"; do
            [ "$key" = "WAIT" ] || printf '%s' "$key"
            sleep 1
        done
        printf 'q'; sleep 1
    } | PATH="$WORK/bin:$PATH" timeout 90 \
        script -qfc "stty rows 60 cols 100; bash $RUNNER -I $folder" "$WORK/$name.log" >/dev/null 2>&1
}
screen() { luajit "$DIR/libs/test-menu-screen-replay.lua" "$WORK/$1.log" 60 100; }
page_exists() { [ -s "$1" ] && echo yes || echo no; }
digits() { local s="$1" i; for ((i = 0; i < ${#s}; i++)); do printf '%s\n' "${s:i:1}"; done; }
# }}}

# {{{ the command line still generates without the menu
bash "$RUNNER" "$WORK/site" "$WORK/pages/cli.html" > /dev/null 2>&1
check "the runner still writes a page without the menu" "$(page_exists "$WORK/pages/cli.html")" "yes"
# }}}

# {{{ the menu: generate, and the tree preview
drive gen "$WORK/site" G $'\r' j j j j j j
check "Go with Generate writes the page into the folder" "$(page_exists "$WORK/site/project-file-server.html")" "yes"
check "the menu comes back and says so" \
    "$(screen gen | grep -c "Wrote $WORK/site/project-file-server.html (")" "1"
check "the panel shows the library's progress" "$(screen gen | grep -c 'Pure HTML file server generated!')" "1"
check "the subfolders are offered" "$(screen gen | grep -cE '\./alpha|\./beta')" "2"
check "hidden folders are not" "$(screen gen | grep -c '\./\.git')" "0"
check "the preview shows the folder under the cursor two levels down" \
    "$(screen gen | grep -cE '^ +(deeper/|d\.txt)')" "2"
# }}}

# {{{ the menu: go into a subfolder, then generate there
drive into "$WORK/site" j j j ' ' j j j ' ' G $'\r'
check "Go into the folder says where it is" "$(screen into | grep -c "Now in $WORK/site/alpha")" "1"
check "and lists that folder's subfolders" "$(screen into | grep -c '\./deeper')" "1"
check "and writes nothing" "$(page_exists "$WORK/site/alpha/project-file-server.html")" "no"
drive subgen "$WORK/site" j j j j j j ' ' G $'\r'
check "choosing a subfolder generates its page" "$(page_exists "$WORK/site/alpha/project-file-server.html")" "yes"
# }}}

# {{{ the menu: the page goes to a typed file
drive elsewhere "$WORK/site" j j j j j j j j j j ' ' G $'\r' "$WORK/pages/site.html"$'\r'
check "a typed file gets the page" "$(page_exists "$WORK/pages/site.html")" "yes"
check "the menu offers it next time" "$(screen elsewhere | grep -cE "\(\*\) $WORK/pages/site.html[[:space:]]*$")" "1"
drive nowhere "$WORK/site" j j j j j j j j j j ' ' G $'\r' "$WORK/no-such-folder/site.html"$'\r'
check "a page that cannot be written is reported" "$(screen nowhere | grep -c 'Failed:')" "1"
# }}}

# {{{ the menu: open the page
drive open "$WORK/site" j j ' ' G $'\r'
check "Open hands the page's address to the opener" \
    "$(grep -cxF "file://$WORK/site/project-file-server.html" "$WORK/opened.txt" 2>/dev/null)" "1"
check "and says so" "$(screen open | grep -c 'Asked the browser to open')" "1"
drive openmissing "$WORK/site" j j ' ' j j j j j ' ' G $'\r'
check "a folder with no page yet is not opened" "$(wc -l < "$WORK/opened.txt")" "1"
check "and the menu says to generate it first" "$(screen openmissing | grep -c 'Generate the page first: there is none at')" "1"
# }}}

# {{{ the menu: serve the page until Ctrl+C
# shellcheck disable=SC2046
drive serve "$WORK/site" j ' ' j j j j j j j j j j $(digits "$PORT") G $'\r' WAIT WAIT $'\003' WAIT
check "Serve starts the server on this machine only" \
    "$(tr -d '\r' < "$WORK/serve.log" | grep -c "Serving HTTP on 127.0.0.1 port $PORT")" "1"
check "Ctrl+C stops it and the menu comes back" "$(screen serve | grep -c "Stopped serving $WORK/site/project-file-server.html")" "1"
check "no server is left running" "$(ps -eo args | grep -c "[h]ttp.server $PORT")" "0"
drive badport "$WORK/site" j ' ' j j j j j j j j j j 8 0 G $'\r'
check "a port below 1024 is refused" "$(screen badport | grep -c 'the port must be 1024-65535 (got 80)')" "1"
# }}}

check "the preview files are cleaned up" "$(find "$WORK/tmp" -mindepth 1 | wc -l)" "0"

rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
