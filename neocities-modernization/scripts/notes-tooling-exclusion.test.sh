#!/usr/bin/env bash
# notes-tooling-exclusion.test.sh (Issue 10-068) -- proves that a tooling
# folder living inside the notes source (the rmail mailbox) never becomes
# site content. It builds a throwaway project and a throwaway notes folder in
# RAM, runs the real sync and the real notes extractor against them, and
# checks what came out.
#
# Pins: the sync skips the mailbox and removes a copy an older sync left
# behind; the sync refuses a configured exclusion that does not exist; the
# extractor never emits a note from inside the mailbox, even when a copy is
# sitting in input/.
#
# Run: bash scripts/notes-tooling-exclusion.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi

"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null
SCRATCH="${DIR}/tmp/shared-memory/notes-tooling-exclusion-test"
rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}"
FAKE_PROJECT="${SCRATCH}/project"
FAKE_NOTES="${SCRATCH}/notes"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ write_fake_project
# write_fake_project <excluded-name>
# A project folder holding only what the sync and extractor read: the real
# libs/ (linked), and a config naming the fake notes folder as its source.
write_fake_project() {
    mkdir -p "${FAKE_PROJECT}/input"
    ln -sfn "${DIR}/libs" "${FAKE_PROJECT}/libs"
    cat > "${FAKE_PROJECT}/config.lua" <<EOF
return {
    sources = {
        notes = {
            enabled = true,
            format = "plaintext",
            directories = {
                {
                    name = "primary",
                    path = "input/notes",
                    external = { source = "${FAKE_NOTES}" },
                    excluded_subdirectories = { "$1" },
                },
            },
        },
    },
    excluded_poems = {},
}
EOF
}
# }}}

# {{{ run_sync
run_sync() {
    luajit -e "
        package.path = '${FAKE_PROJECT}/libs/?.lua;' .. package.path
        local sync = require('external-sync')
        sync.set_project_root('${FAKE_PROJECT}')
        sync.set_verbose(false)
        local result = sync.sync_by_name('primary')
        os.exit(result and result.success and 0 or 1)
    " 2>&1
}
# }}}

# a notes source with one real note and a mailbox beside it
mkdir -p "${FAKE_NOTES}/rmail/inbox" "${FAKE_NOTES}/rmail/hooks"
printf 'a real poem\n' > "${FAKE_NOTES}/a-real-note"
printf 'alice.token = "secret"\n' > "${FAKE_NOTES}/rmail/contacts"
printf 'unsent message\n' > "${FAKE_NOTES}/rmail/inbox/waiting"
printf '#!/bin/sh\nexit 0\n' > "${FAKE_NOTES}/rmail/hooks/on_receive.sh"

write_fake_project "rmail"

# {{{ the sync skips the mailbox and cleans an old copy
mkdir -p "${FAKE_PROJECT}/input/notes/rmail"
printf 'left by an older sync\n' > "${FAKE_PROJECT}/input/notes/rmail/contacts"
run_sync >/dev/null
check "sync succeeds" "$?" "0"
check "real note synced" "$(test -f "${FAKE_PROJECT}/input/notes/a-real-note" && echo yes)" "yes"
check "mailbox not in input/" "$(test -e "${FAKE_PROJECT}/input/notes/rmail" && echo present || echo absent)" "absent"
check "source mailbox untouched" "$(test -f "${FAKE_NOTES}/rmail/contacts" && echo yes)" "yes"
# }}}

# {{{ the extractor never reads inside the mailbox, even when a copy exists
mkdir -p "${FAKE_PROJECT}/input/notes/rmail/inbox"
printf 'should never be a poem\n' > "${FAKE_PROJECT}/input/notes/rmail/inbox/waiting"
extract_output="$(lua "${DIR}/scripts/extract-notes.lua" "${FAKE_PROJECT}" 2>&1)"
check "extractor succeeds" "$?" "0"
poems_json="${FAKE_PROJECT}/input/notes/files/poems.json"
check "one note extracted" "$(grep -c '"category":"notes"' "${poems_json}")" "1"
check "no mailbox file extracted" "$(grep -c 'should never be a poem' "${poems_json}")" "0"
check "extractor names the skipped folder" "$(printf '%s' "${extract_output}" | grep -c 'skipped: rmail')" "1"
# }}}

# {{{ notes are numbered by date, not by the folder's listing order (8-019)
# Created in one order, dated in another, named in a third: the ids must
# follow the dates, oldest first, and a shared date falls back to the name.
rm -rf "${FAKE_PROJECT}/input/notes"
mkdir -p "${FAKE_PROJECT}/input/notes"
for name in middle-b newest oldest middle-a; do
    printf 'a poem called %s\n' "${name}" > "${FAKE_PROJECT}/input/notes/${name}"
done
touch -d '2021-01-01 00:00:00' "${FAKE_PROJECT}/input/notes/oldest"
touch -d '2023-06-01 00:00:00' "${FAKE_PROJECT}/input/notes/middle-a"
touch -d '2023-06-01 00:00:00' "${FAKE_PROJECT}/input/notes/middle-b"
touch -d '2026-09-01 00:00:00' "${FAKE_PROJECT}/input/notes/newest"
lua "${DIR}/scripts/extract-notes.lua" "${FAKE_PROJECT}" >/dev/null 2>&1
check "date-order extraction succeeds" "$?" "0"
order="$(luajit -e "
    package.path = '${DIR}/libs/?.lua;' .. package.path
    local f = io.open('${FAKE_PROJECT}/input/notes/files/poems.json')
    local d = require('dkjson').decode(f:read('*a')); f:close()
    table.sort(d.poems, function(a, b) return a.id < b.id end)
    local names = {}
    for _, p in ipairs(d.poems) do names[#names + 1] = p.id .. '=' .. p.source_file end
    io.write(table.concat(names, ' '))
")"
check "ids follow the dates, the name breaks a tie" "${order}" "0001=oldest 0002=middle-a 0003=middle-b 0004=newest"
# }}}

# {{{ a stale exclusion (folder not in the source) refuses the sync
write_fake_project "no-such-folder"
refusal="$(run_sync)"
check "stale exclusion refused" "$?" "1"
check "refusal names the folder" "$(printf '%s' "${refusal}" | grep -c 'no-such-folder')" "1"
# }}}

# {{{ a name with a slash refuses the sync (it could reach outside input/)
write_fake_project "../escape"
run_sync >/dev/null
check "path-like exclusion refused" "$?" "1"
# }}}

rm -rf "${SCRATCH}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
