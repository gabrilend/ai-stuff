# publish-claude-code-utilities

Keeps `gabrilend/claude-code-utilities` a copy of the owner's skills and
global `CLAUDE.md`, as last committed in the private `~/.claude`
repository. Issue 045.

## Running it

| Command | Does |
|---|---|
| `publish-claude-code-utilities` | copy, check, commit and push if anything changed; silent work otherwise ("is current") |
| `... --dry-run` | build the copy and list what would change; push nothing (works before the public repository exists) |
| `... --create` | create the public repository first if it is missing (the owner, once) |
| `--dir`, `--source`, `--remote`, `--work` | the scripts folder, the private repository, the public one, the RAM working copy; the last three are for tests |

Exit status 0 when published or already current; 1 with a message on
any failure, and nothing pushed.

## What it publishes

An allowlist, read at the private repository's `HEAD` (committed files
only):

- `CLAUDE.md`
- everything under `skills/`, except `skills/synced/` (the service's own)
- a generated `README.md` (skill list, pointer to `gabrilend/ai-stuff`'s
  `scripts/` for the tools the skills call, the source commit)
- `LICENSE`, copied from the ai-stuff repository root (AGPL-3.0)

Files the source no longer has are removed from the copy. File modes
(executable or not) follow git's record. A committed symbolic link stops
the run.

## What stops it

- The public repository missing, without `--create`.
- Nothing to publish at the source's `HEAD` (publishing nothing would
  empty the public copy).
- A file whose name looks like a key file, or whose text holds something
  shaped like an Anthropic or GitHub token or a private key. The message
  names the file and shows the first characters of the match.

## Where things live

- Working copy: `scripts/tmp/shared-memory/claude-code-utilities/` (RAM),
  cloned fresh on every run, so it never carries a dry run's leftovers.
- Tests: `tests/test-publish-claude-code-utilities.sh`, against a scratch
  source and a local bare repository standing in for GitHub.
