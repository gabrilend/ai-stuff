# 035e — One Settings File per Project

| | |
| --- | --- |
| Parent | 035 — share the transcript HTML renderer |
| Blocked by | 035b, 035c, 035d |
| Blocks | nothing here; in double-diaper-dungeon, its issue "the renderer comes from the shared library" |
| Status | complete, 2026-10-04 |

Any project can use the library with one settings file, and a project that
keeps its libraries inside itself can pull a copy.

## Current behavior

Built as intended below: `settings.lua`, `build-site.lua` as module and
command (`--assign-films` picks the second job), `build-transcript-pages
--settings`, `pull-transcript-site`, `README.md`, and an `.info.md` beside
every file. All 34 projects in the ai-stuff repository build. Found while
building: whether a history folder is its repository's top must be decided
on real paths, or a settings path holding `..` reads another project's
evidence out of a folder that has none — the builder now asks the history
reader, which compares real paths.

Before, `build-transcript-pages` took a project folder and a palette file. Where
the transcripts are, where the pages go, and what the history is are all
fixed: `llm-transcripts/`, `llm-transcripts/HTML/`, the project's own git
history. There is nothing to say "read my mirror", "put the pages two
folders down", "use my colours", or "give me films".

## Intended behavior

**A project may hold `transcript-site.settings.lua`** at its root, or name
another file with `--settings`. It returns one table; every field is
optional, and `settings.lua` fills the defaults and refuses a field it does
not know (a misspelt field would otherwise be silently ignored).

| field | type | default | what it is |
| --- | --- | --- | --- |
| `transcripts` | string, folder | `llm-transcripts` | where the `*.md` transcripts are |
| `history` | string, folder | the project | whose git history is the spine |
| `output` | string, folder | `llm-transcripts/HTML` | the site's root: fonts and films go here |
| `pages` | string, folder under `output` | `""` | where the conversation and contents pages go |
| `colours_css` | function → string | — | the project's own colours as a `:root { }` block |
| `palette_file` | string, file | the library's default | used when `colours_css` is absent |
| `fonts` | string, folder | the library's `fonts/` | the font files to copy beside the pages |
| `recap_contents` | boolean | true | 035c |
| `harness_lines` | boolean | true | 035c |
| `attribution` | list of strings | `{ "recorded", "subject", "saved" }` | 035b |
| `title` | string | "How <project> got made" | the contents page's heading |
| `nav` | function → string, string | — | a strip of links for the contents page, and its CSS |
| `films` | table | absent: no films | 035d |
| `scratch` | string, folder | `tmp/shared-memory/transcript-site` | RAM for the films' working files |

Relative paths are read from the project folder.

**The builder is a module as well as a command.** `build-site.lua` returns
`build(project_dir, settings) -> report`, so a project with pages of its own
around the transcripts (double-diaper-dungeon's gate and game pages) calls
it and then writes its own. The report is a table of what it counted:
conversations, commits, groups, commits linked, films used, messages with
no film yet, oversized fenced blocks.

**`README.md` is the guide to using it**: what each part does, the settings
table, how to add it to a project (one command, or a settings file, or a
pulled copy), and how a pulled copy is updated.

**A pulled copy.** `pull-transcript-site <project-dir> [<commit>]` copies the
library, as committed at that commit of the ai-stuff repository (default:
the latest), into `<project-dir>/libs/transcript-site/`, replacing the old
copy, and writes `UPSTREAM` there: the repository, the folder, the commit,
and the date. The owner's words, 2026-10-04: *"treat the vendored copy like
an upstream, and pull a new copy everytime we update a project's
dependencies."* `fonts/` is left out when the project names its own fonts
folder.

## Suggested implementation steps

1. `settings.lua`: defaults, unknown-field refusal, path resolution.
2. `build-site.lua` as module and command; `build-transcript-pages` passes
   `--settings`.
3. `pull-transcript-site`, and its test in a RAM folder.
4. `README.md` and an `.info.md` per file.
5. Run `build-pages-before-push` over the monorepo; every project builds.
