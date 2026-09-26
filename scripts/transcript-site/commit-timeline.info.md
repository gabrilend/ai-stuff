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
- `group(commits) -> list` — runs of `{ commits, transcripts }`.
- `render_index(runs, conversations, opts) -> string` — the page.
  `conversations` maps a transcript path to `{ href, summary }`; `opts` takes
  `title`, `base_path`, `palette_file`.

## Worth knowing

- The order comes from the commits, never from file names or dates, which
  overlap when sessions run side by side.
- Only files directly inside `llm-transcripts/` ending `.md` count as
  transcripts; the `HTML/` pages beside them do not.
- Taken from double-diaper-dungeon's `src/051-commit-timeline.lua`, which
  reads a separate public mirror repository instead.
