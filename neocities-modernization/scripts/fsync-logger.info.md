# fsync-logger.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/fsync-logger: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
scripts/fsync-logger — append stdin to a log file, fsync to physical disk
after EVERY line, and (by default) echo each line onward so a live terminal
still sees it.

Why this exists: a hard GPU lock forces a power-cycle. Even logs written to
real disk can lose their last seconds, because the kernel holds recent writes
in RAM (dirty pages) for up to ~30s before flushing. This helper closes that
window: it calls fsync() on the log after each line, so the moment you SEE a
line, the kernel has already committed it to the platter/SSD. If the machine
hard-locks one instruction later, that line is still on disk after reboot.

This is deliberately, brutally slow — one fsync syscall per line. That is the
whole point: durability over throughput, used only under run.sh --debug while
hunting a freeze. Do not wire it into normal runs.

Path note: unlike most project scripts this takes the absolute target log
path as an argument (the caller — run.sh — has already resolved ${DIR} and
the log directory), so there is no project-relative ${DIR} to hard-code here.

Usage:
  producer | fsync-logger --log /abs/path/to.log          # tee mode: disk + terminal
  producer | fsync-logger --quiet --log /abs/path/to.log  # disk only (background producers)

--help: print the header above and exit, before any work (libs/script-help.sh)
```
