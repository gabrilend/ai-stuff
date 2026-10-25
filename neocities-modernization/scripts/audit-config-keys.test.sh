#!/usr/bin/env bash
# audit-config-keys.test.sh -- proves the config auditor tells a setting that
# nothing reads from one that is read in each of the indirect ways this
# project's code reaches config.lua. It builds a throwaway project in RAM (a
# config file, a few tiny programs, a git index so the auditor can list them),
# runs the real auditor against it, and checks each verdict.
#
# Pins: an unnamed section and an unnamed setting are reported; a setting read
# through a local alias, through a quoted name, through a loop over its
# section, through a list of names elsewhere in config.lua, or through a
# table key listing its settings (`section = { "name" }`) is not; a mention
# inside a comment does not count as a read; a "Read by" comment naming a file
# that never reads the section is reported, and "file.lua:function" is
# understood as a file.
#
# Run: bash scripts/audit-config-keys.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi

"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null
SCRATCH="${DIR}/tmp/shared-memory/audit-config-keys-test"
rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/src"

pass=0; fail=0
# {{{ expect / refuse
# expect <label> <pattern>: the report contains a line matching pattern.
# refuse <label> <pattern>: it does not.
expect() {
    if grep -q -E -- "$2" "${SCRATCH}/report.txt"; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1 (no line matching: $2)"; fi
}
refuse() {
    if grep -q -E -- "$2" "${SCRATCH}/report.txt"; then fail=$((fail+1)); echo "  FAIL - $1 (found: $2)"
    else pass=$((pass+1)); echo "  ok   - $1"; fi
}
# }}}

# {{{ the throwaway project
cat > "${SCRATCH}/config.lua" <<'EOF'
return {
    -- Read by: src/reader.lua
    aliased = { used = 1, unused = 2 },
    -- Read by: src/reader.lua:some_function
    walked = { anything = 1 },
    names = { "alpha", "beta" },
    by_name = { alpha = 1, beta = 2 },
    quoted = { gamma = 1 },
    listed = { delta = 1 },
    -- Read by: src/never.lua
    only_in_comment = { x = 1 },
    nobody = { y = 1 },
}
EOF
cat > "${SCRATCH}/src/reader.lua" <<'EOF'
local config = dofile("config.lua")
local a = config.aliased
print(a.used)
for k, v in pairs(config.walked) do print(k, v) end
for _, n in ipairs(config.names) do print(config.by_name[n]) end
local key = "gamma"
print(config.quoted[key])
-- a list of a section's settings, read through config[section]
local REQUIRED = { listed = { "delta" } }
for section, keys in pairs(REQUIRED) do print(config[section][keys[1] ]) end
-- config.only_in_comment.x is mentioned here only in a comment
EOF
cat > "${SCRATCH}/src/never.lua" <<'EOF'
print("this file reads nothing from config")
EOF
git -C "${SCRATCH}" init -q
git -C "${SCRATCH}" add config.lua src/reader.lua src/never.lua
# }}}

"${DIR}/scripts/audit-config-keys" "${SCRATCH}" > "${SCRATCH}/report.txt"
status=$?

if [ "${status}" -eq 1 ]; then pass=$((pass+1)); echo "  ok   - exits 1 when something is unread"
else fail=$((fail+1)); echo "  FAIL - exit status ${status}, want 1"; fi

expect "a section nothing names is reported"            '^UNREAD SECTION  nobody$'
expect "a setting nothing names is reported"            '^UNREAD SETTING  aliased\.unused'
refuse "a setting read through an alias is not"         'aliased\.used'
refuse "a section walked by a loop is fully read"       'walked'
refuse "a table indexed by a config list is read"       'by_name'
refuse "a setting read by a quoted name is read"        'quoted'
refuse "a section named as a list of its settings is read" 'listed'
expect "a comment mention does not count as a read"     '^UNREAD SECTION  only_in_comment$'
expect "a stale Read by comment is reported"            'STALE COMMENT   only_in_comment: .*src/never\.lua, which never reads it'
refuse "file.lua:function is read as the file"          'STALE COMMENT   walked'

rm -rf "${SCRATCH}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
