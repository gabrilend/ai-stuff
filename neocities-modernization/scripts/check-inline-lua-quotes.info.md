# check-inline-lua-quotes.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/check-inline-lua-quotes: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
check-inline-lua-quotes
Verify that no stray double quote appears inside a shell script's inline Lua
chunks, because one there silently corrupts the program it is embedded in.

General description (for a CEO): parts of this pipeline hand a snippet of one
programming language to another by wrapping it in quotation marks. Put a
quotation mark inside the snippet and the wrapper ends early -- the rest of the
snippet stops being a program and becomes a list of loose words, which the
receiving program then mistakes for instructions. Nothing reports an error; it
simply does the wrong thing. This tool reads the scripts and reports any
snippet whose quotation marks do not balance, so the mistake is caught by
running one command instead of by a stage failing an hour into a build.

The failure that prompted it (Issue 10-065): a comment inside one such chunk
read `-- to be guarded by "if INFERENCE_SERVER is not empty", and an`. The
shell ended the chunk at the first quote and passed `if INFERENCE_SERVER is not
empty...` to luajit as arguments. A module that infers the project root from
its first argument then took the word "is" as the root, and the stage died on
"Failed to load config from is/config.lua". `bash -n` sees nothing wrong,
because the script IS still valid shell -- it just means something else now.

Usage:
  scripts/check-inline-lua-quotes [--dir PATH] [--file FILE]...
    --dir PATH   the project folder (default below)
    --file FILE  a file to check; repeatable. Without any, the known callers.
  A word with no flag in front of it stops the script (Issue 10-076): files
  are named with --file, so a mistyped flag is never read as a file name.
Exit status: 0 when every chunk balances, 1 when any does not.

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `check_file()`

```
Walk a file, and for every line that opens an inline chunk, count double quotes
until the line that closes it. A correct chunk has exactly two: the opener and
the closer. Any other count means a quote inside the Lua source.

The opening pattern is assembled from pieces rather than written out, so this
checker does not flag its own source when pointed at itself.
```
