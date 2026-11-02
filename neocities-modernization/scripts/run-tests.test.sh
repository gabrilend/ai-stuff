#!/usr/bin/env bash
# run-tests.test.sh (Issue 10-010) -- proves the suite runner finds the suites
# the project's naming conventions name and no others, tells a pass from a
# failure from a skip, shows a failing suite's own output, and exits 1 exactly
# when something failed.
#
# It builds a throwaway project in RAM holding a handful of tiny suites whose
# outcome is known, runs the real scripts/run-tests against it with its own
# log folder (so it never touches the log folder of a run that is running
# this test), and reads what came out.
#
# Run: bash scripts/run-tests.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
RUNNER="$DIR/scripts/run-tests"

"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null
SCRATCH="${DIR}/tmp/shared-memory/run-tests-test"
rm -rf "${SCRATCH}"
FAKE="${SCRATCH}/project"
LOGS="${SCRATCH}/logs"
mkdir -p "${FAKE}/src" "${FAKE}/libs/deeper" "${FAKE}/scripts"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ the fake project's suites
# Passing, in each naming convention.
printf 'print("fine")\n' > "${FAKE}/src/good.test.lua"
printf 'print("fine")\n' > "${FAKE}/libs/older-test.lua"
printf 'echo fine\n' > "${FAKE}/scripts/good.test.sh"
# Failing, with a line the report must show.
printf 'print("the reason it broke")\nos.exit(1)\n' > "${FAKE}/src/broken.test.lua"
# Skipping: exits 0 but says it could not run here.
printf 'print("SKIP: no server here")\n' > "${FAKE}/libs/needs-server-test.lua"
# The suite is handed the project folder as its first argument.
printf 'if arg[1] ~= "%s" then os.exit(1) end\n' "${FAKE}" > "${FAKE}/src/gets-dir.test.lua"
# Not suites: an older data check, a nested file, a non-test file. Each would
# fail if it were run, so running one shows up as a failure.
printf 'os.exit(1)\n' > "${FAKE}/src/test-legacy.lua"
printf 'os.exit(1)\n' > "${FAKE}/libs/deeper/nested.test.lua"
printf 'os.exit(1)\n' > "${FAKE}/src/module.lua"
# }}}

# {{{ discovery
listed="$("$RUNNER" "${FAKE}" --list | tr '\n' ' ')"
check "lists exactly the suites the conventions name" "${listed}" \
    "libs/needs-server-test.lua libs/older-test.lua scripts/good.test.sh src/broken.test.lua src/gets-dir.test.lua src/good.test.lua "
# }}}

# {{{ a full run
out="$("$RUNNER" "${FAKE}" --logs "${LOGS}" 2>&1)"
status=$?
check "a failing suite makes the run fail" "${status}" "1"
check "the failing suite is named" "$(printf '%s\n' "${out}" | grep -c '^  FAIL  src/broken.test.lua')" "1"
check "its own output is shown" "$(printf '%s\n' "${out}" | grep -c 'the reason it broke')" "1"
check "a passing lua suite is ok" "$(printf '%s\n' "${out}" | grep -c '^  ok    src/good.test.lua')" "1"
check "a passing shell suite is ok" "$(printf '%s\n' "${out}" | grep -c '^  ok    scripts/good.test.sh')" "1"
check "the older -test.lua name is run" "$(printf '%s\n' "${out}" | grep -c '^  ok    libs/older-test.lua')" "1"
check "a suite that says SKIP is a skip, not a pass" \
    "$(printf '%s\n' "${out}" | grep -c '^  skip  libs/needs-server-test.lua.*SKIP: no server here')" "1"
check "the suite is given the project folder" "$(printf '%s\n' "${out}" | grep -c '^  ok    src/gets-dir.test.lua')" "1"
check "the summary counts each outcome" \
    "$(printf '%s\n' "${out}" | grep -c 'Suites: 6  passed: 4  failed: 1  skipped: 1')" "1"
check "every suite's output is logged" "$(ls "${LOGS}" | wc -l | tr -d ' ')" "6"
# }}}

# {{{ filters and an all-green run
out="$("$RUNNER" "${FAKE}" --logs "${LOGS}" --only good 2>&1)"
check "a run with nothing failing exits 0" "$?" "0"
check "a filter runs only the matching suites" \
    "$(printf '%s\n' "${out}" | grep -c 'Suites: 2  passed: 2  failed: 0  skipped: 0')" "1"
"$RUNNER" "${FAKE}" --logs "${LOGS}" --only no-such-suite >/dev/null 2>&1
check "a filter that matches nothing is an error" "$?" "1"
# }}}

# {{{ a suite that hangs is stopped
printf 'while true do end\n' > "${FAKE}/src/hangs.test.lua"
out="$("$RUNNER" "${FAKE}" --logs "${LOGS}" --timeout 1 --only hangs 2>&1)"
check "a hanging suite fails the run" "$?" "1"
check "and is reported as timed out" "$(printf '%s\n' "${out}" | grep -c 'hangs.test.lua.*timed out after 1s')" "1"
# }}}

# {{{ bad arguments
"$RUNNER" "${FAKE}" --timeout soon >/dev/null 2>&1
check "a non-numeric timeout is refused" "$?" "1"
"$RUNNER" "${SCRATCH}/nowhere" --list >/dev/null 2>&1
check "a folder with no project is refused" "$?" "1"
# }}}

rm -rf "${SCRATCH}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
