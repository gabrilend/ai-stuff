# run-tests

Runs every test in the project, several at a time, and reports which passed,
failed, or could not run. `run.sh` runs it before the first stage of every
build (after the pre-flight gate); one failure stops the build (Issue 10-010).

## Usage

`scripts/run-tests [--dir PATH] --jobs N [--match TEXT]`

| option | meaning |
| --- | --- |
| `--jobs` | how many tests run at once (required; `run.sh` passes the processor count) |
| `--match` | only tests whose file name contains TEXT |

## Which tests

Found by name, so a new test needs no list:
`src/*.test.lua`, `src/*-test.lua`, `libs/*.test.lua`, `libs/*-test.lua`,
`scripts/*.test.sh`. A Lua test runs as `luajit FILE DIR`, a shell test as
`bash FILE`; exit 0 passes. A test whose last line starts with `SKIP` could
not run here (the batched-embedding test, when the inference server is down)
and is listed separately, not counted as passed.

## Output

Each test's output in `tmp/shared-memory/tests/<test>.log`; one summary line,
then the tests that could not run and those that failed. Exit 1 when any
test failed.
