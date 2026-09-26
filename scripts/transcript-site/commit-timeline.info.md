# commit-timeline.lua

Builds the front page: the project's commits, oldest first, grouped into runs
that each end at the commit which saved a conversation, with a link to that
conversation's page.

## Public functions

- `read_commits(project_dir) -> list` — every commit that touched the
  project's folder, oldest first. Each is `{ hash, subject, date, body,
  transcripts }` (strings; `body` nil when the message has none;
  `transcripts` a list of `llm-transcripts/<name>.md` paths it touched).
  Paths are relative to the project folder, so a project inside a larger
  repository reads the same as one that is its own repository.
- `rename_map(project_dir) -> table` — old transcript path to the path it has
  now, following chains of renames git recorded.
- `resolve(path, map) -> string` — the name a path goes by now.
- `attribute(commits, evidence)` — sets on each commit `conversation` (a
  transcript key or nil), `turn` (number or nil) and `how`: `"recorded"` (a
  transcript records making it, by hash, or by subject when exactly one
  transcript records that subject — history rewrites move hashes),
  `"saved"` (it touched exactly one main conversation's transcript, a
  helper's counting as its parent's), or nil (no evidence). `evidence` is
  `{ by_hash, by_subject, parent_of, is_main }`, built by `build-site.lua`.
- `group(commits) -> list` — runs of `{ commits, conversation }`:
  consecutive commits with the same conversation, or the same lack of one.
- `render_index(runs, conversations, opts) -> string` — the page.
  `conversations` maps a transcript key to `{ href, summary, elsewhere }`
  (`elsewhere` names the project a conversation is filed under when it is
  not this one); `opts` takes `title`, `base_path`, `palette_file`.

## Worth knowing

- **Which conversation made a commit is decided by evidence, never by
  position.** The rule taken from double-diaper-dungeon — a run belongs to
  whatever transcript its last commit touched — hung world-edit-to-execute's
  first 220 commits off a one-turn transcript, because the first commit to
  touch any transcript was a bulk import. A run with no evidence says "No
  conversation is recorded for these commits."
- A commit recorded by its conversation links (↗) to the turn that made it.
- Each commit's title stays on one line, cut with an ellipsis when the window
  is narrow; the whole title shows on hover and when the commit is unfolded.
- The order comes from the commits, never from file names or dates, which
  overlap when sessions run side by side.
- Only files directly inside `llm-transcripts/` ending `.md` count as
  transcripts; the `HTML/` pages beside them do not.
- Taken from double-diaper-dungeon's `src/051-commit-timeline.lua`, which
  reads a separate public mirror repository instead.
