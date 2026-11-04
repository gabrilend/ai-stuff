# Issue #045: Publish the skills as claude-code-utilities

## Current Behavior

Steps 1–6 are built: `publish-claude-code-utilities` (with its `.info.md`)
and `tests/test-publish-claude-code-utilities.sh` (run it for the count;
all passing when written).
A dry run against the real `~/.claude` (at its commit b41baf3) listed 27
files: `CLAUDE.md`, `LICENSE`, `README.md` and 13 skills; every one was
read before anything was offered for publishing. Waiting on the owner:
the one-time `--create` and first push, and the hook (question 1).

Before this, the owner's skills (`~/.claude/skills/`) and global
`CLAUDE.md` live only in the `~/.claude` repository (really
`/mnt/mtwo/.claude`), which has no remote. The tools the skills call
(the commit route, the issue checker, the transcript exporter, the hook
gates) are already public, in `gabrilend/ai-stuff` under `scripts/`.
`gabrilend/claude-code-utilities` does not exist yet.

## Intended Behavior

A public repository, `gabrilend/claude-code-utilities`, holding:

- every skill in `~/.claude/skills/` **as last committed** there (never a
  half-finished edit from a session still working; a skill not yet
  committed, such as one being written, appears the first sync after its
  commit), except `skills/synced/`, which holds the service's own skills;
- `CLAUDE.md`, as last committed, published whole (owner, 2026-10-21:
  "A", publish as it is);
- a generated `README.md` saying what the repository is, that the skills
  call tools living in `gabrilend/ai-stuff` (`scripts/`), pointing there
  rather than copying them (owner: "point."), and which `~/.claude`
  commit the copy was made from;
- `LICENSE`, the same AGPL as `ai-stuff`.

Nothing else from `~/.claude` is ever published: the copy is an allowlist
(the two paths above), never "everything but". Before pushing, the
script refuses if any file it would publish looks like a credential (a
file named like `.credentials*`, or an Anthropic or GitHub key pattern in
its text), naming the file.

**Kept current automatically** (owner: "We can attach it to the ai-stuff
git pull, so that it's always up to date."). `publish-claude-code-utilities`
runs from an ai-stuff git hook; it is cheap when nothing changed (no
commit, no push).

The working copy lives in RAM (`scripts/tmp/shared-memory/` →
`/dev/shm/ai-stuff-scripts/claude-code-utilities/`), cloned from GitHub
when missing, so no second permanent checkout exists to drift.

Creating the GitHub repository is the one irreversible step, so the
script never does it on its own: it stops with a message unless run with
`--create`, which the owner runs once.

## Suggested Implementation Steps

1. `publish-claude-code-utilities` (LuaJIT), with `--dry-run` (build the
   copy, print the file list and what changed, push nothing), `--create`,
   and overrides for the source repository and the remote so it can be
   tested without GitHub. An `.info.md` beside it.
2. The copy: list the allowlisted paths at the source's `HEAD`
   (`git ls-tree`), write each from `git show HEAD:<path>`, remove files
   the source no longer has, write the README and LICENSE.
3. The credential check, before any commit.
4. Commit only when the copy differs, with a message naming the source
   commit; push.
5. Tests: a scratch source repository and a local bare repository as the
   remote; a committed skill is published, an uncommitted edit is not,
   `synced/` is not, a removed skill is removed, a credential-looking file
   stops it, a second run with nothing new makes no commit.
6. Read every file that goes out (the house rule: nothing is published
   unread), show the owner the file list from `--dry-run`, and only then
   the owner's `--create` and the first push.
7. The git hook (question 1), installed by a small installer like
   `install-pages-hook`.
8. Point at it from the move-project plan and the skills' own docs where
   they mention `~/.claude`.

## Open Questions

1. **Which hook.** A pull of ai-stuff brings nothing into `~/.claude`,
   where the skills change, so a hook run after a pull would mostly find
   nothing new. A hook before a push of ai-stuff publishes whenever the
   owner publishes anything else. Pull (`post-merge`), push
   (`pre-push`, beside the transcript pages), or both?
2. (Answered 2026-10-21: "let that issue handle it") The lodge skill,
   still being written by another session, is published by the first
   sync after it is committed; nothing special is done for it.

## Related

- `044-moving-a-project-keeps-its-conversations.md` (the move-project
  skill, the first skill made with this in view).
- `install-pages-hook`, `transcript-site/build-pages-before-push` (the
  existing pre-push hook).
- `~/.claude/.gitignore` (lets every skill and `settings.json` in;
  `settings.json` is not published).
