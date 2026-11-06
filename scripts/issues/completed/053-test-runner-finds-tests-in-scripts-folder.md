# Issue 053: test-runner finds tests kept in a project's scripts/ folder

## Current Behavior

`test-runner.sh` looks for tests in `tests/`, `src/tests/` and the project
root. delta-version keeps its six tests (`test-census-projects.sh`,
`test-compository.sh` and the rest) beside its tools in
`delta-version/scripts/`, so running the runner on delta-version says "no
tests found" and exits 2, and none of those tests run during a build.
neocities-modernization's two real tests in `scripts/` are missed the same way.

## Intended Behavior

The runner also finds tests in `<project>/scripts/`, without picking up the
tools there whose names merely start with `test-`.

## Suggested Implementation Steps

1. Survey what `scripts/test-*` files the projects actually hold, to see which
   are tests and which are tools.
2. Add `scripts/` to `discover_tests()` with a rule that keeps the tools out.
3. Say so in the runner's "WHAT COUNTS AS A TEST" header, with the reason.
4. Add a test that builds a pretend project and checks `--list`.

## Decisions

- **Only names ending in `.sh` count in `scripts/`.** The survey found every
  real test there ends in `.sh` (delta-version's six, neocities-modernization's
  `test-model-propagation.sh` and `test-seed-reproducibility.sh`), while the
  extensionless `test-*` files are tools: neocities' `test-html-generation`,
  `test-diversity-quick` and `test-effil-simple` generate output or probe a
  library rather than pass or fail. The executable-or-.sh rule used elsewhere
  would have run those generators on every build.
- **Cost of that rule:** an extensionless test runner kept in `scripts/` is not
  found -- today soren-ds's `scripts/test-twin` and gameboy-color-rpg's
  `scripts/test-build`. Moving such a file to `tests/`, or adding `.sh`, is the
  fix; the header says so. Guessing from file contents was rejected as too
  easy to get wrong silently.
- **Only the top-level `scripts/` folder is searched**, not a `scripts/` deeper
  in the tree, matching how the other places are fixed folders.
- Lua files in `scripts/` are not picked up; no project keeps a Lua test there.

## What Happened

Built on branch `claude/test-runner-scripts-folder`.

- `test-runner.sh`: `discover_tests()` now also lists `scripts/test-*.sh` and
  `scripts/test_*.sh` as programs (run with bash when not executable); the
  header gained the `scripts/` line and a paragraph on why it is stricter.
- `tests/test-test-runner-discovery.sh` (18 checks): a pretend project with a
  test in every place the runner looks plus look-alikes that must stay out
  (an extensionless generator and an ordinary tool in `scripts/`, a note, a
  `-done` file, non-executable root files, a nested `scripts/`); checks the
  `--list` holds exactly the seven tests, then runs a small project with one
  passing and one failing `scripts/` test and checks the exit code and
  summary. The RAM tiers are pointed into the scratch folder. Against the old
  runner 5 of the 18 checks fail.
- `--list` on the real checkout now shows delta-version's six tests and
  neocities-modernization's two `.sh` tests; soren-ds still has none found.

## Renumbered

**2026-11-04:** this issue was 039, a number main gave a different issue in
the 2026-11-03 push, so it moved to the next free number, 053.
