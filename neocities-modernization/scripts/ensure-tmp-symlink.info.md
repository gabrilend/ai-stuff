# ensure-tmp-symlink.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/ensure-tmp-symlink: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
ensure-tmp-symlink

Sets up the project's two-tier RAM scratch, per the CLAUDE.md convention:

  tmp/                -> /tmp/neocities-modernization/        (RAM, EXEC allowed)
  tmp/shared-memory/  -> /dev/shm/neocities-modernization/    (RAM, noexec)

The project's tmp/ points at a per-project dir under /tmp/, which is RAM where
/tmp is a tmpfs and — crucially — allows execution, so compiled binaries and
dlopen'd .so files can live and run there. Nested inside it, tmp/shared-memory/
points at /dev/shm/, which every modern Linux guarantees to be RAM but commonly
mounts noexec: the right home for logs, compiled build artifacts, and other
NON-executable data. Rule of thumb: things you RUN go in tmp/; things you WRITE
(logs, dumps, caches) go in tmp/shared-memory/.

Idempotent and self-healing: it creates whatever is missing and repoints a
symlink that aims at the wrong target (a symlink holds no data, so re-aiming it
loses nothing). It refuses loudly only when a real directory or file sits where
a symlink belongs — those bytes might be someone's, and moving them into
volatile RAM would be worse than a loud refusal that asks a human to look.

Usage:
  scripts/ensure-tmp-symlink                          # uses hard-coded DIR
  scripts/ensure-tmp-symlink /path/to/project/root    # overrides DIR
  source scripts/ensure-tmp-symlink                   # bash callers can source

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `ensure_targets_exist()`
(No comment above it in the source.)

### `ensure_symlink()`

```
Make ${1} a symlink to ${2}. Shared by both tiers so they obey identical rules:
create when missing, repoint a wrong-target symlink in place, refuse a real
directory/file loudly.
```
