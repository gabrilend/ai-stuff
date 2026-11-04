# pull-transcript-site

Copies the library into a project, as committed, and writes down which
commit it was.

## Usage

    pull-transcript-site <project-dir> [--commit <commit>] [--without <name>]...
                         [--into <folder>] [--dir <scripts-dir>]

- `--commit` — default the latest commit. Never the files on disk, so a
  half-edited library is never what a project gets.
- `--without` — leave a file or folder of the library out (for example
  `fonts`, when the project names its own). Refused when the library has no
  such thing.
- `--into` — default `libs/transcript-site`.

## What it does

1. `git archive` of the library's folder at that commit, unpacked into the
   project's `tmp/shared-memory/pull-transcript-site/` (RAM).
2. Leaves out what was asked.
3. Writes `UPSTREAM`: the repository, the folder, the full commit hash, the
   date, and what was left out.
4. Replaces the old copy with the new one whole, only once everything above
   worked, so a failed pull leaves the old copy as it was.

## The rule it serves

The owner's, 2026-10-04: *"treat the vendored copy like an upstream, and pull
a new copy everytime we update a project's dependencies."* A pulled copy is
never edited in the project. A change goes into the library, is committed,
and is pulled.
