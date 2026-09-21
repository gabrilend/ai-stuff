# Issue #026: The skeleton half of init-project cannot run outside the monorepo

## Current Behavior

`init-project.sh` does two jobs in one pass. The first is ordinary and wanted
everywhere: lay out a project's standard folders, write the table of contents
if it is absent, wire the two RAM scratch tiers to a `tmp/` symlink, and add
the missing lines to `.gitignore`. The second is the sandbox: a shared clone
into tmpfs, a sparse checkout, a bind-mount plan, a launcher, and a carry-back
watcher.

The second job is what forces the first to live inside the monorepo. The
script's `DIR` is the monorepo root; `provision_sandbox` does a
`git clone --shared` of the monorepo and a sparse checkout of one directory in
it; `collect_ignored_paths` asks git what is ignored; the borrowed object store
is keyed by the monorepo's basename. A project that is not a directory inside a
monorepo checkout has none of that, and the script cannot get as far as the
folders.

So a project outside the monorepo gets nothing. Double Diaper Dungeon lives at
`/mnt/cmdo/ritz/games/tq/ai-stuff/double-diaper-dungeon`, which is not under
`/mnt/mtwo/programming/ai-stuff`, and every piece of the skeleton was made by
hand there: the fourteen directories, the `docs/HTML/.gitkeep`, the
`.file-index-counter`, the `.gitignore`, `/tmp/<name>/tmp`,
`/dev/shm/<name>`, the `tmp/` symlink and the `tmp/shared-memory` symlink
inside it, and a table of contents typed rather than generated. Every one of
those is a thing the script already knows how to do, and doing them by hand is
exactly what the standing rule against making things manually is meant to
prevent. The one that actually bites is the symlink pair: get the order wrong
and you end up with `tmp/tmp/tmp`, which is the bug `link_ram_directories`
already carries a comment about.

## Intended Behavior

The skeleton stands on its own, and the sandbox is the part that needs a
monorepo.

    init-project.sh --skeleton-only <path>

Given any path, inside a monorepo or not, this makes the standard folders,
the intent directories, the table of contents when absent, the RAM tiers and
their two symlinks, and the `.gitignore` additions. It does not clone, does
not mount, does not write a launcher, and does not write the sandbox notice
into `CLAUDE.md`, because there is no sandbox to describe. It says so plainly
in its report rather than being silent about the half it skipped.

The same path is taken automatically when the named project is not inside the
monorepo: rather than failing on a clone that cannot work, the script does the
half it can, prints which half it did, and names the reason. A tool that
refuses a reasonable request because of a part the request did not ask for is
a tool people stop reaching for.

Three consequences worth stating, because they are the ones that make this
more than an argument rearrangement:

- **The project's own `.gitignore` lines differ.** Inside the monorepo the
  script adds `scripts/enter-sandbox.sh`, which is the launcher's path. With
  no sandbox there is no launcher, so that line is noise. The skeleton-only
  path adds `tmp` and stops.
- **`.file-index-counter` should be part of the skeleton.** It is not today.
  Every project that numbers its files starts it by hand at `000`, and a
  counter that starts wrong is a renumbering job later. Nineteen projects on
  disk have one; none of them got it from the tool.
- **The sandbox's single-writer rule does not apply.** That rule exists
  because `carry-back.sh` owns the real project directory while a sandbox is
  live. With no sandbox the skeleton writes to the real directory directly,
  which is the ordinary case and needs no ceremony.

## Suggested Implementation Steps

1. Split `create_project_skeleton`, `link_ram_directories` and
   `write_project_gitignore` from the paths that reach `DIR`. They already
   take a target as an argument; the work is in what calls them and what they
   assume about that target.
2. Add `--skeleton-only <path>` to `parse_arguments`. The path may be absolute
   or relative, and need not be under the monorepo root. Reject only a path
   that is a file.
3. Teach `require_tools` that bubblewrap, rsync and the unprivileged-namespace
   check are the sandbox's needs, not the skeleton's. A machine without
   bubblewrap should still be able to lay out a project.
4. Move the `.file-index-counter` seed into `create_project_skeleton`, written
   only when absent, at `000`. Add a line about it to the generated table of
   contents.
5. Make `write_project_gitignore` take the wanted lines rather than holding
   them, so the skeleton-only path can pass a shorter list.
6. In `main`, detect that the project path is not under the monorepo root and
   take the skeleton-only path with a printed reason rather than failing.
7. Extend `report` to say which half ran. The existing report already
   distinguishes what is contained from what is not; this is the same shape of
   honesty about what was and was not done.
8. Test against three targets: a project inside the monorepo (both halves run,
   unchanged from today), a project outside it (skeleton only, with the
   reason printed), and a re-run over Double Diaper Dungeon, which must be a
   no-op that changes nothing, since every piece of its skeleton is already
   there and correct.

## Related Documents and Tools

- `init-project.info.md`, which documents both halves as one thing and will
  need the split described in it.
- `carry-back.info.md`, whose single-writer rule is scoped to the sandbox and
  should say so.
- `/mnt/cmdo/ritz/games/tq/ai-stuff/double-diaper-dungeon`, the project that
  went without, and the test case for step 8.

## Notes

Raised by the developer in that project's `desire/what-would-be-better.md`,
where the observation was written down as the skeleton was being built by
hand.
