# write-run-overrides.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/write-run-overrides: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
write-run-overrides
Stamp this run's command-line choices onto the shared notepad in RAM
(tmp/shared-memory/run-overrides.lua) so every helper program the pipeline launches
afterward reads the same answers -- the embedding model, especially.

General description (for a CEO): the pipeline runs as a series of separate
little programs. Before this existed, a flag like --model reached only the
programs run.sh remembered to hand it to, and the rest quietly used the
default from the config file -- so the website could be built half with one
model and half with another. This tool writes the operator's choices down in
one place, once, at the start of the run. It is written fresh every run, so a
choice from a previous run can never leak into this one.

Usage:
  scripts/write-run-overrides [--dir PATH] [--key value]...
  e.g. scripts/write-run-overrides --dir "$DIR" --model qwen3-embedding:4b
--dir defaults to the hard-coded project root; pass it (as run.sh does) to
be safe. A word with no flag in front of it stops the script (Issue 10-076). Empty values are skipped: an absent key means "no override; use
config.lua", so `--model ""` correctly records no model override at all.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `setup_dir_path(provided)`
(No comment above it in the source.)

### `parse_args(args)`

```
Every "--key value" pair becomes an override, skipping empty values so
callers can pass through-unset flags verbatim without building the argument
list conditionally. (The project folder, --dir, is read before this.)
```
