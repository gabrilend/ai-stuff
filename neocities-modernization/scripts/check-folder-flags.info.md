# check-folder-flags.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/check-folder-flags: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
check-folder-flags

WHAT IT DOES (for a CEO): every program in the project must learn where
the project is from one flag, --dir PATH, read by the shared reader
(libs/project-dir.lua, or libs/project-dir.sh for shell scripts), which
also stops the program on a stray word. This lists every program that
does not, so none slips back to the old way -- the old way turned a
mistyped flag's value into the project folder (Issue 10-076). It changes
nothing.

What counts as a program (the execute bit is not a reliable sign here):
  scripts/*             (not .md / .info files)
  *.sh                  at the project root
  src/*.lua, libs/*.lua with a "#!" first line
  src/libs tests        (*.test.lua, *-test.lua)
A program passes when its text names "project-dir.lua" or
"project-dir.sh". One that takes no project folder at all -- a library
that is sourced or loaded rather than run, say -- passes with a comment
containing "project-dir: none" and the reason; one that reads --dir and
refuses stray words with a parser of its own (run.sh, whose parser also
checks every value) passes with "project-dir: own" and the reason. Both
kinds are printed, so each stays visible.

Usage:
  scripts/check-folder-flags [--dir PATH] [--list-programs]
    --list-programs  print every program it would check, one per line, and
                     nothing else (scripts/write-info-notes --missing uses it)
Exit status: 0 when every program passes, 1 otherwise.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `lines_of(command)`

```
The output of a shell command, one string per line.
```

### `slurp(path)`
(No comment above it in the source.)

### `programs()`

```
Every program, as paths relative to DIR, sorted.
```
