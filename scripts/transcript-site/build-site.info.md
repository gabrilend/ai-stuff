# build-site.lua (and build-transcript-pages, assign-films)

The only file that joins the library's three parts. Reads a project's
transcripts once, hands each part the tables it needs, and writes the site
where the project's settings say.

## As a module

- `build(settings) -> report` — the whole site. `settings` from
  `settings.load`. The report:

  | field | type | what it is |
  | --- | --- | --- |
  | `conversations` | number | pages written |
  | `not_transcripts` | list of strings | files left alone |
  | `commits`, `groups`, `linked` | numbers | commits read, groups drawn, commits whose button lands on a page |
  | `how` | rule name → number | which rule decided how many |
  | `elsewhere` | number | commit lines read from other projects in the repository |
  | `films_used`, `films_unmatched` | numbers or nil | films copied; messages with no film yet |
  | `oversized` | list of `{ file, lines, language }` | fenced blocks over 200 lines |
  | `output` | string | the site's root |

- `assign_films(settings)` — chooses films for every message that has none.
- `shape(conversation, settings) -> conversation` — applies the two
  switches (`harness_lines`, `recap_contents`). Used by both of the above,
  so a message has the same place on the page and in the films.
- `read_transcripts(settings) -> transcripts, not_transcripts` — every
  transcript, read and shaped, sorted by name.
- `print_report(report)` — says what the build saw.
- `settings` — `settings.lua`, for a caller that has only this file.
- `WORTH_MENTIONING` — 200, the fenced-block length worth listing.

## As a command

    luajit build-site.lua <project> [<settings-file>]
    luajit build-site.lua --assign-films <project> [<settings-file>]

`build-transcript-pages` and `assign-films` are the friendly front doors.

## Evidence from the rest of the repository

A project inside a larger repository also takes commit lines from every
other `llm-transcripts/` folder in it, down to three levels: a conversation
started at the repository's top commits to every project in it. This
project's own transcripts win a tie. Skipped when the history folder is its
repository's top, compared by real path — the first version compared the
written path, and read 61 "other projects'" lines out of a mirror with none.

## Rebuilt before every push

`install-pages-hook <repository>...` gives a repository a `pre-push` hook
running `build-pages-before-push`, which rebuilds every project whose
transcripts or latest commit are newer than its `llm-transcripts/HTML/`
pages, and stops the push if one cannot be built. It looks only at the
default output folder; a project with its own `output` builds itself.

## When it stops

- The project is not in a git repository (the table of contents is its
  history), or its transcripts folder holds no transcripts.
- A settings field the library does not know, or of the wrong kind.
- A transcript the reader refuses: the exporter's format moved, and a site
  quietly missing a conversation would look complete.
- A film choice naming a film that has left the folder.
