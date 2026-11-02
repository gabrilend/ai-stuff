# Testing Guide

How the project's tests are found, run and written. (Issue 10-010.)

## Running them

```
scripts/run-tests [DIR]                 # every suite, one line each
scripts/run-tests [DIR] --only flat-html # only suites whose path contains this
scripts/run-tests [DIR] --list          # which suites would run
./run.sh ... --run-tests                # the same, as a pre-flight check
```

`scripts/run-tests` prints `ok`, `FAIL` or `skip` per suite, then the last 15
lines of every failing suite's output, then a count. It exits 1 if any suite
failed. Each suite's full output is kept in `tmp/shared-memory/run-tests/`.
A suite that runs longer than `--timeout` seconds (default 300) counts as
failed.

`./run.sh --run-tests` (or the "Run Test Suites First" checkbox in `run.sh -I`)
adds the suites to the pre-flight gate (`scripts/preflight-gate`, issue
10-069): they run before any stage starts, and a failure stops the run with
nothing started. It is opt-in because the suites take about a minute, most of
it `scripts/exit-status.test.sh` waiting on processes it kills on purpose.

## What counts as a suite

A file directly inside `src/`, `libs/` or `scripts/` named:

| Name | Run with |
|---|---|
| `<module>.test.lua`, `<module>.<topic>.test.lua` | `luajit` |
| `<module>-test.lua` (the older spelling) | `luajit` |
| `<script>.test.sh` | `bash` |

Each is run from the project folder with the project folder as its first
argument. The older `src/test-*.lua` and `scripts/test-*` files are checks
against the real corpus, caches or GPU; they are not discovered, so run them
by hand on the machine that has the data.

## Writing one

New suites follow the newest ones (`src/page-head.test.lua`,
`src/flat-html-generator.*.test.lua`, `scripts/preflight-gate.test.sh`):

- **A header comment** that says what the suite guards and why it exists --
  usually the bug or the issue it pins -- and how to run it directly.
- **The project folder from `arg[1]`** (Lua) or `$1` (Bash), falling back to
  the file's own location or the hard-coded project path.
- **A `check(name, condition)` helper** printing `  ok   name` or
  `  FAIL name -- detail` for each check, and a closing
  `N passed, M failed` line. Exit 0 only when nothing failed.
- **Scratch files** in `tmp/` or `/tmp/neocities-modernization/tmp/<suite>`,
  removed at the end. Never write into `input/` or `assets/` beyond what the
  pipeline itself would write (the page suites sync `page-templates/` into
  `input/pages/` exactly as `run.sh` does).
- **Fixtures, not the corpus.** A handful of made-up poems with the fields the
  code reads. A suite that also checks the real data does so as a separate
  part that is skipped when the data is absent.

## Skipping

When a suite cannot run at all here -- no inference server, no rsync -- it
prints a line starting `SKIP:` with the reason and exits 0; the runner then
reports `skip`, not `ok`. When only some checks need something missing (the
owner's compiled threading library, the real poem list), those checks print
`  skip - name: reason`, are not counted, and the rest still run. A check
that skips must still run, and still fail, wherever the thing it needs is
present: skipping is for "not on this machine", never for "broken".

## Things a fresh checkout needs

- `assets/` must exist (empty is enough): the page generator refuses to load
  without it, and the `flat-html-generator.*` suites load it. The runner says
  so up front when it is missing.
- The hard-coded project path (`/mnt/mtwo/programming/ai-stuff/...`) is the
  default for scripts that are not given one; pass the project folder, or
  point that path at the checkout.
