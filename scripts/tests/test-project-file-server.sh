#!/usr/bin/env bash
#
# test-project-file-server.sh - proves project-file-server writes a page with
# no CSS and no JavaScript, whatever the names in the folder it scans
# (issue 007).
#
# In plain terms: builds a small folder tree in a scratch folder, some of whose
# names are hostile -- a file called <script>.md, a folder called $(touch ...)
# that a shell would run, names with quotes, ampersands and spaces -- and runs
# the file server on it. Then it reads the page and checks: no <style>, no
# <script>, no style= or on...= attribute anywhere; every hostile name shows
# as text; no command hidden in a name ran; every folder with something in it
# is a <details> with a <summary>; links are file:// links with the awkward
# characters percent-encoded; and the scan stops three levels down. It also
# checks the runner finds its library beside itself, so any folder can be
# scanned, and that an option it does not know is refused.
#
# Usage:
#   tests/test-project-file-server.sh [scripts-dir]

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

RUNNER="${DIR}/project-file-server"
SCRATCH="$(mktemp -d /tmp/claude-1000/test-project-file-server.XXXXXX)"

PASSED=0
FAILED=0

# {{{ pass / fail / check
pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
check() {
    local description="$1"
    shift
    if "$@"; then pass "${description}"; else fail "${description}"; fi
}
# }}}

# {{{ page_has / page_lacks
PAGE="${SCRATCH}/page.html"
page_has()   { grep -qF -- "$1" "${PAGE}" || { printf '        (not in page: %s)\n' "$1"; return 1; }; }
page_lacks() { ! grep -qiE -- "$1" "${PAGE}" || { grep -niE -- "$1" "${PAGE}" | head -3 | sed 's/^/        /'; return 1; }; }
# }}}

# The tree. The canary folder is where a name's hidden command would write:
# the runner is started from inside it, and the commands name no folder.
tree="${SCRATCH}/tree"
canary="${SCRATCH}/canary"
mkdir -p "${tree}/plain/deeper/deepest" "${canary}"
printf 'x\n' > "${tree}/plain/notes.md"
printf 'x\n' > "${tree}/plain/deeper/three.txt"
printf 'x\n' > "${tree}/plain/deeper/deepest/four.txt"
printf 'x\n' > "${tree}/<script>alert(1)<.md"
printf 'x\n' > "${tree}/quote\"and'apostrophe.txt"
printf 'x\n' > "${tree}/salt & pepper #1.txt"
printf 'x\n' > "${tree}/<b onclick=x>.txt"
mkdir -p "${tree}/\$(touch ran-dollar)"
mkdir -p "${tree}/\`touch ran-backtick\`"
printf 'x\n' > "${tree}/\$(touch ran-dollar)/inside.txt"
mkdir -p "${tree}/empty-folder"
mkdir -p "${tree}/.hidden"
printf 'x\n' > "${tree}/.hidden/secret.txt"

# Run from inside the canary folder: a name's hidden "touch" would land there.
said="$(cd "${canary}" && "${RUNNER}" "${tree}" "${PAGE}" 2>&1)"
status=$?

printf '\nThe page is written\n'
check "the runner succeeds on a folder outside the monorepo" test "${status}" -eq 0
check "the page exists" test -s "${PAGE}"

printf '\nNo CSS and no JavaScript\n'
check "no <style> element"           page_lacks '<style'
check "no <script> element"          page_lacks '<script'
check "no style= attribute"          page_lacks '[[:space:]]style[[:space:]]*='
check "no on...= event attribute"    page_lacks '<[^>]*[[:space:]]on[a-z]+[[:space:]]*='
check "no javascript: link"          page_lacks 'javascript:'
check "no <link> to a stylesheet"    page_lacks '<link'

printf '\nNames are text, never markup or commands\n'
check "a file called <script>... shows as text" page_has '&lt;script&gt;alert(1)&lt;.md'
check "a file called <b onclick=x> shows as text" page_has '&lt;b onclick=x&gt;.txt'
check "quotes and apostrophes are escaped" page_has 'quote&quot;and&#39;apostrophe.txt'
check "an ampersand is escaped" page_has 'salt &amp; pepper #1.txt'
check "a \$(...) folder name did not run" test ! -e "${canary}/ran-dollar"
check "a backtick folder name did not run" test ! -e "${canary}/ran-backtick"
check "the \$(...) folder is still listed, with what is inside it" \
    page_has 'inside.txt'

printf '\nFolders and links\n'
check "a folder with files is a <details> with a <summary>" \
    page_has '<summary><a href="file://'"${tree}"'/plain">plain/</a>'
check "an empty folder is a plain link" page_has '>empty-folder/</a>'
check "hidden files and folders are left out" page_lacks 'secret\.txt|\.hidden'
check "a space and a # in a name are percent-encoded in its link" \
    page_has 'salt%20%26%20pepper%20%231.txt"'
check "a quote in a name is percent-encoded in its link" \
    page_has 'quote%22and%27apostrophe.txt"'
check "every <details> is closed" \
    test "$(grep -c '<details>' "${PAGE}")" -eq "$(grep -c '</details>' "${PAGE}")"
check "the scan lists what is three levels down" page_has '>three.txt</a>'
check "and stops there" page_lacks 'four\.txt'

printf '\nThe runner\n'
check "an unknown option is refused" \
    bash -c '! "$1" --nonsense >/dev/null 2>&1' _ "${RUNNER}"
check "a folder that does not exist is refused" \
    bash -c '! "$1" "$2" >/dev/null 2>&1' _ "${RUNNER}" "${SCRATCH}/nowhere"
check "-o names the output when the folder is given first" \
    bash -c '"$1" "$2" -o "$3" >/dev/null 2>&1 && test -s "$3"' _ "${RUNNER}" "${tree}/plain" "${SCRATCH}/second.html"
check "with no output named, the page goes into the scanned folder" \
    bash -c '"$1" "$2" >/dev/null 2>&1 && test -s "$2/project-file-server.html"' _ "${RUNNER}" "${tree}/plain/deeper"

rm -rf "${SCRATCH}"
printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
