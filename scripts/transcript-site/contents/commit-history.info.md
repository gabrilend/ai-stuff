# commit-history.lua

Part of the table of contents. Reads a folder's git history into a list of
commits, oldest first. Reads git and nothing else.

## Public functions

- `read(folder, transcripts) -> list` — every commit, oldest first.
  `transcripts` (string, default `"llm-transcripts"`) is the transcripts
  folder's path inside `folder`. Raises if the history cannot be read or none
  of it is understood. Each commit:

  | field | type | what it is |
  | --- | --- | --- |
  | `hash` | string | its full hash |
  | `source` | string | the hash the transcripts know it by: its `Mirrored-from:` hash, or its own |
  | `subject` | string | the first line of its message |
  | `date` | string | `YYYY-MM-DD` |
  | `body` | string or nil | the rest of the message, trailers removed |
  | `transcripts` | list of strings | transcript files it touched, as `<transcripts>/<name>.md` |

- `rename_map(folder) -> table` — old transcript path to the path it has now,
  following chains of renames git recorded.
- `resolve(path, map) -> string` — the name a path goes by now.
- `is_repository_top(folder) -> boolean` — whether the folder is the top of
  its repository, comparing real paths. Raises when it is in no repository.

## Two kinds of history

- **The folder is its repository's top** (a standalone project, or a public
  mirror): every commit, empty ones included. A mirror writes an empty
  commit where a project commit touched no transcript; without it, a
  stretch of work would vanish from the story.
- **The folder is inside a larger repository** (a project in the ai-stuff
  monorepo): only commits that touched it, with paths written from it.

## Trailers

`Mirrored-from:` becomes `source`; `Co-Authored-By:` and `Claude-Session:`
are dropped. They are for machines, and on a page they would be the same
line under every commit.

## Why the commits

A folder of transcripts has no reading order: the files are named for spans
of days that overlap when sessions run side by side. The commits are the
only true chronology.

Taken from double-diaper-dungeon's `src/051-commit-timeline.lua` and this
folder's older `commit-timeline.lua`, which read one kind of history each.
