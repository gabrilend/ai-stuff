# 8-059: Unify temp/ and tmp/ into a single tmp/ symlinked to RAM-backed storage

## Current behavior

The project's root-level `tmp/` is a symbolic link to `/tmp/neocities-modernization/`
(tmpfs-backed RAM storage). The shell pipeline's ZIP-extraction working space
and the Lua side's worker-script staging both route through this single path.
A helper `scripts/ensure-tmp-symlink` materialises the symlink on demand and
fails loudly if the path is present but pointing somewhere unexpected.

The first pass of the migration covered `scripts/update`, the now-deleted
`scripts/parallel-word-pages.lua`, and `.gitignore`. A subsequent audit (the
documentation staleness report written to `tmp/` during this issue's work)
identified a second pass of consumers that still write to raw `/tmp/` or
to the old `temp/` path. The current state, after the second pass, is:

- All entry-point scripts that produce ephemeral output call the helper.
- All production source files that previously hardcoded `/tmp/...` now use
  a project-relative path under `tmp/`. This makes the project portable: a
  copy of the repository at a different absolute path produces ephemera at
  that new path's `tmp/`, not at a single shared `/tmp/` location that
  could collide between parallel copies.
- One library, `libs/fuzzy-computing.lua`, retains its `/tmp/` writes
  because the file has zero callers in tracked code and its only exposed
  functions are marked DEPRECATED. Migrating its paths would imply a
  maintenance commitment the rest of the codebase does not honour. The
  file should be deleted in a follow-up.
- The exploratory stub `scripts/parallel-word-pages.lua` has been removed.
  The design it represented has been superseded by issue 10-035 (which
  proposes an effil-orchestrator pattern inside `src/generate-word-pages.lua`
  rather than a separate driver script).

## Intended behavior

(unchanged) The project has a single ephemeral-output directory, `tmp/`,
which is a symbolic link to a project-specific subdirectory of the system
tmpfs at `/tmp/neocities-modernization/`. Every script that writes
ephemeral files goes through this single path.

Every entry point that produces ephemeral output ensures the symlink and
its target exist before any write, via a shared helper. If the symlink
is missing or points to the wrong place, the helper recreates it.

## Suggested implementation steps

### First pass (completed in commit f45f587c)

1. Created helper `scripts/ensure-tmp-symlink`. Accepts `${DIR}` as first
   argument with a hard-coded default, targets `/tmp/neocities-modernization/`,
   idempotent, fails loudly when the path exists but is not the expected
   symlink.
2. Updated `scripts/update` to invoke the helper and to write its
   extraction working directory under `tmp/extract-...` rather than
   `temp/extract-...`.
3. Updated `.gitignore` to ignore `tmp` instead of `temp/`.
4. Removed `temp/` and `tmp/` from the working tree.

### Second pass (this commit)

5. Fix `scripts/update-words` line 30: change `BACKUP_DIR="${DIR}/temp/preserved-files-$$"`
   to `BACKUP_DIR="${DIR}/tmp/preserved-files-$$"` and call the helper
   before the preserve step. This is the bug that motivated re-opening
   the issue: the first pass missed this caller, so a subsequent
   `./run.sh --update-words` would have silently re-created `temp/` as
   a real directory.

6. Migrate `scripts/start-ollama-cuda.sh` lines 50, 63, 70: replace
   `/tmp/ollama-cuda.log` with a path under the project `tmp/`. Call the
   helper before the first write.

7. Migrate the production Lua source files that previously hardcoded
   `/tmp/...`:
   - `src/centroid-generator.lua:56` — embedding input shuttle.
   - `src/similarity-engine.lua:94, 508, 621` — embedding input shuttle
     and per-user progress files. The library has a callable `DIR` since
     all entry points pass it; thread it down.
   - `src/generate-word-pages.lua:155` — word embedding input shuttle.
   - `src/ollama-manager.lua:49, 151, 158` — ollama log and embedding
     test JSON.

8. Migrate the test files:
   - `src/test-mass-diversity-generator.lua:31, 87, 123, 204` — four
     test output directories.
   - `src/test-report-generator.lua:342` — test fixture path.
   - `libs/hope-card-formatter-test.lua:167` — test fixture path.
   - `libs/html-threaded/test.lua:12, 33, 60, 69` — test fixture path.

9. Delete `scripts/parallel-word-pages.lua`. The file was untracked,
   never functional (ends in three `IMPLEMENTATION INCOMPLETE` error
   lines), and is superseded by the design proposed in issue 10-035.

10. Skip `libs/fuzzy-computing.lua`. The file has no callers in tracked
    code and its `M.generate` function is marked DEPRECATED. Migrating
    its paths would imply ongoing maintenance the file does not warrant.
    Flag for deletion in a follow-up.

## Files involved

### First pass
- `scripts/ensure-tmp-symlink` (new)
- `scripts/update`
- `.gitignore`

### Second pass
- `scripts/update-words`
- `scripts/start-ollama-cuda.sh`
- `src/centroid-generator.lua`
- `src/similarity-engine.lua`
- `src/generate-word-pages.lua`
- `src/ollama-manager.lua`
- `src/test-mass-diversity-generator.lua`
- `src/test-report-generator.lua`
- `libs/hope-card-formatter-test.lua`
- `libs/html-threaded/test.lua`
- `scripts/parallel-word-pages.lua` (deleted)

## Considerations

- The system tmpfs is 16 GB on the current development host. Peak ZIP
  extraction working size has been observed at around 2.3 GB. If the
  project is later deployed somewhere with a smaller tmpfs (a low-memory
  VM, a Termux Android host), the extraction working directory may need
  to revert to disk-backed storage. In that case, split the helper into
  two: one for small ephemera (tmpfs) and one for large working sets
  (disk-backed under a separate name).
- The helper enforces the symlink invariant by failing loudly rather
  than auto-migrating an existing real directory. This follows the
  project-wide principle "prefer error messages and breaking
  functionality over fallbacks": a silent migration of someone's data
  into tmpfs (where it evaporates on reboot) would be worse than a loud
  refusal that prompts human attention.
- The portability gain from routing everything through the project-relative
  `tmp/` is concrete: two parallel checkouts of the same repository at
  different paths produce ephemera at distinct tmpfs targets, with no
  cross-talk. The previous raw `/tmp/foo.json` pattern was a hidden
  source of cross-checkout collision.
- `libs/fuzzy-computing.lua` should be reviewed for deletion. Its `M.generate`
  is marked DEPRECATED and a tree-wide search finds no `require` calls for
  the module.
- The Lua audit suggested by issue 10-035 (parallelizing word page
  generation) is still open. The work here makes that future change easier
  by giving the to-be-spawned workers a stable, portable working directory.
