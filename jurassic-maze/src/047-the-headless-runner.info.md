# 047-the-headless-runner

The whole thing with no window and no engine.

Read this page rather than the source.

## What it is for

**This is the one that makes the project testable.** A simulation observed only
by a person watching it has no tests, because "did that look right" is not an
assertion.

It runs under a bare `luajit`, not under the game engine, and that is half of
what it is for: if a simulation file has quietly grown a dependency on the
window, this fails to load rather than passing while being wrong.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `parse(argv)` | array of strings | the options table. **Raises on an unknown flag.** |
| `run(root, argv)` | | the report table, having printed it |

An unknown flag is refused rather than ignored, because a misspelled flag that is
silently dropped produces a run with the defaults while somebody believes they
changed something.

## Options

`--seed --width --depth --layers --terraces --capacity --scene --ticks`, plus
`--describe` for the maze's numbers with no simulation, `--row` for one
tab-separated line, and `--quiet`.

## It is also a program

Invoked directly as `luajit src/047-the-headless-runner.lua <root> <args>`. See
the note in the source for why `luajit -e` cannot be made to work here.

`arg[0]` is the file luajit was actually asked to run, so the self-invocation
fires only when that file is this one — never when the viewer or a test loads the
module.
