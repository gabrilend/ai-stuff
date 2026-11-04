# deploy-to-neocities.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/deploy-to-neocities: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Chunked, adaptive, resumable deploy of output/ to the live site's
similar-different/. Replaces the stock `neocities push` path that uploads one
file per request, never backs off, and dies partway under rate limiting.

General description (for a CEO): the old deploy fired tens of thousands of
single-file requests at the server until it got tired and hung up, losing the
run. This sends many files per request, speeds up while the server is happy and
backs off the instant it pushes back, and -- because it first asks the live
site what it already has -- it only sends what is missing, so a re-run resumes
where the last one stopped instead of starting over.

Pieces: libs/neocities-api.lua (status-honest curl layer), libs/neocities-sync
(the tested adaptive control loop + diff). This script wires them to the real
build and the real key.

Usage:
  scripts/deploy-to-neocities [--dir PATH] [--dry-run] [--yes] [--prune] [--only PREFIX]
    --dry-run     list + diff only; change nothing
    --yes         skip the confirmation prompts
    --prune       after uploading, DELETE remote files under similar-different/
                  that are not in the local build (a true mirror). Destructive;
                  asks separately. Upload-then-prune keeps the site working
                  throughout (current content goes up before stale is removed).
                  The COMPLETE stale list is written to tmp/prune-list (RAM),
                  whether or not you confirm the delete; the terminal shows
                  the first 50 and points at the file for the rest.
    --only PREFIX restrict BOTH passes to remote paths under PREFIX (e.g.
                  similar-different/gallery) -- for testing on a small slice

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `pacing(kind)`

```
The request pacing for one kind of call, from config.lua deploy (Issue
10-071); a missing number is an error naming it.
```

### `load_key()`
(No comment above it in the source.)

### `local_files()`

```
deploy's excludes (debug-logs/, the GPU bin, anchored at output/ root). Returns
array of { remote=, abspath=, cost=bytes, bytes=, sha1= }. sha1 lets us upload
only files whose CONTENT differs from the live copy (so a changed build updates
stale pages, not just missing ones). bytes/cost are the same value (diff_upload
sorts by .bytes; the adaptive loop batches by .cost).
```

### `remote_sha()`

```
Uses the no-path (full, RECURSIVE) site listing -- a path-scoped list returns
only one directory level, which would make the diff think everything nested is
missing. Filter to our section by prefix.
```

### `confirm(prompt)`
(No comment above it in the source.)

### `bucket_of(remote)`

```
Plain string strip, NOT a Lua pattern: REMOTE_DIR contains "-", which is a
magic pattern character (lazy quantifier), so a pattern would fail to match.
```

### `write_prune_list(paths)`

```
to the RAM-backed tmp/ so the complete list outlives the terminal scrollback
and can be fed to other tools (sort, grep, a manual delete) -- even when it is
far longer than is sane to eyeball. Returns the absolute path written.

We deliberately do NOT shell out to ensure-tmp-symlink here: the listing step
above already drove a curl through tmp/neocities-curl.cfg, so by the time a
prune preview runs the tmp/ tmpfs symlink is provably materialised. (It also
honours the project rule against using exec for directory-targeting work.) If
tmp/ somehow is not there, the assert fails loudly rather than papering over a
missing directory -- a real error we would want surfaced, not swallowed.
```
