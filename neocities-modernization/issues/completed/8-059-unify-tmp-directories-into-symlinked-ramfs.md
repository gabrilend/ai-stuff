# 8-059: Unify temp/ and tmp/ into a single tmp/ symlinked to RAM-backed storage

## Current behavior

The project has two separate directories at the repository root for ephemeral
output, neither of which honours the project-wide convention that ephemeral
files belong on a tmpfs-backed symlink:

- `temp/` is created by the shell pipeline (`scripts/update` line 120) for
  per-run ZIP extraction working space. Subdirectories of the form
  `extract-<timestamp>/` are created at the start of an update run and removed
  at the end (line 210). Over time, extra artefacts have accumulated in this
  directory from unrelated work (hope-card demos, preserved-files snapshots,
  numeric-index test output). The directory is listed in `.gitignore`.
- `tmp/` is created by Lua callers (`scripts/parallel-word-pages.lua` lines
  132–135 and 262–263) for worker scripts and intermediate word lists. It also
  holds stale test artefacts (pagination and chronological-anchor test outputs,
  a Bluesky test JSON pair, a TTS research notes folder, an analysis report
  `cleanup-report.md`). The directory is NOT in `.gitignore`.

Both directories exist as plain on-disk directories rather than as symlinks
into the system `/tmp/` (a tmpfs filesystem). Neither script enforces the
symlink invariant — they each call `mkdir -p` against a bare relative path,
which silently creates a real directory if nothing is there, and silently
no-ops if the path already exists in any form.

This violates the project-wide rule that "logs and other ephemeral outputs
should be written to the project local `tmp/` directory, which should be a
symlink to a project-specific directory located in the system `/tmp/`
directory, in order to be stored in RAM rather than disk."

## Intended behavior

The project has a single ephemeral-output directory, `tmp/`, which is a
symbolic link to a project-specific subdirectory of the system tmpfs at
`/tmp/neocities-modernization/`. Every script that writes ephemeral files
goes through this single path.

Every entry point that produces ephemeral output ensures the symlink and its
target exist before any write, via a shared helper. If the symlink is missing
or points to the wrong place, the helper recreates it.

The `temp/` directory does not exist. The previous `temp/` consumers (the
update pipeline's ZIP extraction working space) write to `tmp/` instead.

## Suggested implementation steps

1. Create a new helper script `scripts/ensure-tmp-symlink` that:
   - Accepts `${DIR}` as its first argument with a hard-coded default at the
     top of the script (per the project-wide script conventions).
   - Defines a tmpfs target path `/tmp/neocities-modernization/`.
   - Creates the tmpfs target if missing.
   - If `${DIR}/tmp` does not exist, creates the symlink.
   - If `${DIR}/tmp` exists but is not a symlink to the expected target,
     fails loudly so the user can decide whether to migrate or override.
   - Is safe to call from both bash (`source` or invoke) and Lua
     (`os.execute`).

2. Update `scripts/update`:
   - Source or invoke `ensure-tmp-symlink` near the top of the script, after
     `DIR` is resolved.
   - Change the working-directory path on line 120 from `${DIR}/temp/extract-...`
     to `${DIR}/tmp/extract-...`.

3. Update `scripts/parallel-word-pages.lua`:
   - At the two places where it currently does `os.execute('mkdir -p ...tmp')`
     (line 135 in the unused worker-script generator, line 263 in `main`),
     replace with a call to `scripts/ensure-tmp-symlink` so the invariant is
     enforced from Lua too.

4. Migrate existing contents:
   - Delete all current `temp/*` contents (stale ZIP extractions, hope-card
     demo files, preserved-files snapshots — all reproducible or unrelated).
   - Delete all current `tmp/*` contents (per the analysis in the existing
     `tmp/cleanup-report.md`, all entries are either stale test output or
     reproducible).
   - Remove the now-empty `temp/` and `tmp/` directories.
   - Create `/tmp/neocities-modernization/`.
   - Create `tmp` as a symlink to that target.

5. Update `.gitignore`:
   - Remove the `temp/` entry.
   - Add `tmp` (symlink entry; matches the symlink itself so `git status`
     stays clean).

6. Verify by running:
   - `ls -la tmp` shows the symlink resolving into `/tmp/`.
   - `scripts/ensure-tmp-symlink "${DIR}"` is idempotent across repeated runs.
   - A test update run lands its working files under `tmp/extract-...`.

## Files involved

- `scripts/ensure-tmp-symlink` (new)
- `scripts/update` (TEMP_EXTRACT_DIR path)
- `scripts/parallel-word-pages.lua` (untracked WIP; path fix only, not
  committed as part of this issue — the author of that file will commit it
  themselves when ready)
- `.gitignore` (replace `temp/` with `tmp`)
- `issues/8-progress.md` (record completion)

## Considerations

- The system tmpfs is 16 GB on the current development host. Peak ZIP
  extraction working size has been observed at around 2.3 GB across multiple
  concurrent `extract-*/` directories — well within budget. If this project
  is later deployed somewhere with a smaller tmpfs (a low-memory VM, a
  Termux Android host), the extraction working directory may need to revert
  to disk-backed storage. In that case, split the helper into two: one for
  small ephemera (tmpfs) and one for large working sets (disk-backed under
  a separate name).
- The existing `tmp/cleanup-report.md` is itself a generated analysis
  artefact that will be lost in this migration. Its recommendations have
  been absorbed into this issue file.
- The new helper enforces the symlink invariant by *failing loudly* rather
  than auto-migrating an existing real directory. This follows the
  project-wide principle "prefer error messages and breaking functionality
  over fallbacks": a silent migration of someone's data into tmpfs (where it
  evaporates on reboot) would be worse than a loud refusal that prompts
  human attention.
