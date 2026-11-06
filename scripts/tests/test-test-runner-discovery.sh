#!/usr/bin/env bash
#
# test-test-runner-discovery.sh - proves test-runner.sh finds each kind of test
# a project keeps, and leaves alone the tools that only look like tests.
#
# In plain terms: builds a pretend project in a scratch folder with a test in
# every place the runner looks (tests/, src/tests/, the root, and scripts/ the
# way delta-version keeps them), plus files that must not be picked up: a
# retired -done copy, a note, a non-executable root file, and in scripts/ an
# extensionless generator and an ordinary tool. Then it asks the runner for
# its --list and checks the list holds exactly the tests. A second, small run
# lets the scripts/ test actually execute, to show a found test is also run.
# The RAM tiers are pointed into the scratch folder, so the real /tmp and
# /dev/shm are not touched.
#
# Usage:
#   tests/test-test-runner-discovery.sh [scripts-dir]

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

RUNNER="${DIR}/test-runner.sh"
SCRATCH="$(mktemp -d /tmp/claude-1000/test-runner-discovery.XXXXXX)"
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
mkdir -p "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}"

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

# {{{ make_program
# make_program <path> [exec]: a tiny passing shell test; executable when asked.
make_program() {
    mkdir -p "$(dirname "$1")"
    printf '#!/usr/bin/env bash\necho "%s ran"\n' "${1##*/}" > "$1"
    if [ "${2:-}" = exec ]; then chmod +x "$1"; fi
}
# }}}

# {{{ listed / not_listed
# The runner's --list output for the pretend project, kept once.
LIST=""
listed()     { grep -qx "$1" <<<"${LIST}" || { printf '        (list was:\n%s)\n' "${LIST}"; return 1; }; }
not_listed() { ! grep -q "$1" <<<"${LIST}"; }
# }}}

project="${SCRATCH}/project"

# The tests, one in each place the runner looks.
make_program "${project}/tests/test-alpha.sh"
make_program "${project}/src/tests/test_beta.sh"
make_program "${project}/test-root-exec" exec
mkdir -p "${project}/tests"
printf 'print("lua ran")\n' > "${project}/tests/test_gamma.lua"
make_program "${project}/scripts/test-delta.sh" exec
make_program "${project}/scripts/test_epsilon.sh"
make_program "${project}/check-zeta" exec

# Look-alikes that must stay out.
make_program "${project}/scripts/test-generator" exec      # extensionless tool
make_program "${project}/scripts/build.sh" exec            # ordinary tool
printf 'notes\n' > "${project}/scripts/test-plan.md"
make_program "${project}/tests/test-old.sh-done"           # retired file
make_program "${project}/test-root-plain"                  # not executable, no .sh
make_program "${project}/check-plain"                      # not executable
make_program "${project}/deep/scripts/test-nested.sh" exec # scripts/ only at the top

LIST="$("${RUNNER}" "${project}" --list 2>&1)"
status=$?

check "--list succeeds on the pretend project" test "${status}" -eq 0
check "tests/ shell test is found"            listed "program  tests/test-alpha.sh"
check "src/tests/ shell test is found"        listed "program  src/tests/test_beta.sh"
check "executable root test is found"         listed "program  test-root-exec"
check "tests/ lua test is found as lua"       listed "lua      tests/test_gamma.lua"
check "scripts/test-*.sh is found"            listed "program  scripts/test-delta.sh"
check "scripts/test_*.sh is found even when not executable" \
                                              listed "program  scripts/test_epsilon.sh"
check "root check-* is found"                 listed "program  check-zeta"
check "extensionless scripts/ tool is left out" not_listed "scripts/test-generator"
check "ordinary scripts/ tool is left out"    not_listed "scripts/build.sh"
check "a note in scripts/ is left out"        not_listed "test-plan.md"
check "a retired -done file is left out"      not_listed "test-old.sh-done"
check "a plain, non-executable root file is left out" not_listed "test-root-plain"
check "a non-executable check-* is left out"  not_listed "check-plain"
check "scripts/ deeper in the tree is not searched" not_listed "test-nested.sh"
check "exactly seven tests are listed" \
    test "$(grep -c . <<<"${LIST}")" -eq 7

# A found scripts/ test is also run, and its result counted.
small="${SCRATCH}/small"
make_program "${small}/scripts/test-runs.sh"
printf '#!/usr/bin/env bash\necho failing on purpose\nexit 1\n' > "${small}/scripts/test-fails.sh"
said="$("${RUNNER}" "${small}" --quiet 2>&1)"
status=$?
check "a run over scripts/ tests exits 1 when one fails" test "${status}" -eq 1
check "the summary counts one pass and one failure" \
    bash -c "grep -q '1 passed' <<<\"\$1\" && grep -q '1 failed' <<<\"\$1\"" _ "${said}"

rm -rf "${SCRATCH}"
printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
