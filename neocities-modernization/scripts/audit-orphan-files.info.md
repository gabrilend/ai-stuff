# audit-orphan-files

Lists the modules in `src/` and `libs/` that nothing in the live project uses.

## Why it exists

Issue 10-060 asked for a "broader orphan audit": a dead module stays in the
tree for months when its own test keeps it looking used, and dead modules that
name each other keep each other looking used. The same issue records why the
check must be careful: the project once deleted the embedding generator as
dead, because its only caller was Lua written inside a shell script.

## Usage

    scripts/audit-orphan-files [--dir PATH]          list orphans
    scripts/audit-orphan-files [--dir PATH] --why    also show which files name each one

Exit status: 0 no orphans, 1 some found.

## How it decides

| Term | Meaning |
|---|---|
| module | a `.lua` file in `src/` (any depth) or at the top of `libs/`; these are judged. Folders inside `libs/` are self-contained libraries and are not judged |
| script | a file in `scripts/` or a `.sh` file at the project root; never judged dead, and anything it names is alive |
| names | the file's name without `.lua`, appearing as a whole word (letters, digits, `-` and `_` count as word characters) anywhere in another tracked program, outside whole-line comments. This covers `require("x")`, `luajit src/x.lua`, and Lua inside shell scripts |
| test / demo | a file with "test" in its path / a file in `demos/` or the phase-demo picker. Being named only by these does not make a module alive |

A module is alive when it can be reached by following names from a starting
point: every script, and every program that is not a module, a test or a demo
(the self-contained libraries inside `libs/` subfolders, for instance).
Everything not reached is reported. Reachability, rather than "something names
it", is what catches a group of modules that only name each other: each has a
referrer, but nothing that runs leads to any of them.

The report has four lists (named by nothing; only by tests; only by demos; only
by other dead modules), then, for information, the scripts nothing else calls.
Most of those are run by hand on purpose.

## Limits

A module loaded by a name built at run time is invisible to it (none exist as of
2026-10-04). A short, common module name can match unrelated text and look
used; that error only goes the safe way. The report is a list to check by hand,
never a list to delete from.

## Test

`scripts/audit-orphan-files.test.sh` builds a throwaway project with one module
of each kind and checks every verdict.
