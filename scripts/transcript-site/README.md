# transcript-site

Turns a project's saved conversations with an AI assistant into a small
website: one readable page per conversation, a table of contents that tells
the project's story commit by commit, and — when a project asks — a small
looping film beside every message.

It started as double-diaper-dungeon's website and became a library on
2026-10-04 (ai-stuff scripts issue 035 and its 035a–035e). That game now
builds its site from a pulled copy of this folder, and the pages it writes
are byte for byte the ones that were live before the switch.

## The three parts

The library is three parts that never load each other. Each takes plain
tables in and hands plain tables or HTML out; `build-site.lua` is the only
file that joins them, and a test fails if any part reaches into another.

| part | folder | what it does |
| --- | --- | --- |
| **the conversation page** | `conversation/` | reads a transcript into a table (`transcript-reader.lua`) and draws it as a page (`conversation-page.lua`): her words on the left, the assistant's on the right, the model named where it changes, the harness's recaps folded away, an id on every commit line |
| **the table of contents** | `contents/` | reads git history (`commit-history.lua`), decides which conversation made each commit (`attribution.lua`), and draws every commit oldest first with a button into its conversation (`contents-page.lua`) |
| **the films** | `films/` | looks at each gif once and describes it (`film-describer.lua`, through `model-server.lua`), matches every message to the gif nearest in meaning, keeping neighbours different, and writes each choice down forever (`film-matcher.lua`) — see `films/README.md` |

The one thing two parts must agree on is the name of a commit line's id,
`commit-<first seven hex digits>`. The conversation page owns that rule
(`commit_anchor`); the builder asks it and hands the answer to the table of
contents, so neither part knows the other's markup.

Beside the parts: `settings.lua` (a project's settings, read and checked),
`site-palette.lua` and `default-palette.lua` (colours), `libs/` (markdown,
the page head, JSON), `fonts/` (the monospace the pages ship).

## Commands

| command | does |
| --- | --- |
| `build-transcript-pages [project] [--settings file]` | builds the site and prints what it saw |
| `assign-films [project] [--settings file]` | chooses a film for every message that has none (needs the model server) |
| `start-the-film-models [project] [--settings file]` | starts the local model server the films need |
| `pull-transcript-site <project> [--commit c] [--without name]...` | copies this library, as committed, into a project |
| `build-pages-before-push [repository] [--jobs n]` | builds every committed project's pages, several at once, drawing only the pages whose transcript or display code changed; what the pre-push hook runs |
| `install-pages-hook <repository>...` | installs that hook, and ignores the pages in git |

Each starts with a comment saying what it is; `--help` prints it.

## Adding it to a project

**The smallest way: nothing at all.** A project with `llm-transcripts/` in a
git repository builds with

    build-transcript-pages /path/to/project

and gets its pages in `llm-transcripts/HTML/`, in double-diaper-dungeon's
colours, with no films. `install-pages-hook` rebuilds them before every push.

**To change anything, add a settings file.** Put
`transcript-site.settings.lua` in the project's top folder (or name a file
with `--settings`). It returns one table; every field is optional, and a
field the library does not know is refused rather than ignored.

```lua
return {
  title = "How the lighthouse got made",
  palette_file = "assets/palette.lua",
  attribution = { "recorded" },
}
```

| field | type | default | what it is |
| --- | --- | --- | --- |
| `transcripts` | string, folder | `llm-transcripts` | where the `*.md` transcripts are |
| `history` | string, folder | the project | whose git history is the table of contents' spine |
| `output` | string, folder | `llm-transcripts/HTML` | the site's root: `fonts/` and `films/` go here |
| `pages` | string, folder under `output` | `""` | where the conversation pages and the table of contents go |
| `colours_css` | function(project) → string | — | the project's own colours, as a `:root { }` block |
| `palette_file` | string, file | `default-palette.lua` | a palette file (see `site-palette.info.md`), used when `colours_css` is absent |
| `fonts` | string, folder | this folder's `fonts/` | where the two font files are |
| `recap_contents` | boolean | `true` | draw the list of recaps at the top of a page |
| `harness_lines` | boolean | `true` | keep the lines above the first request as a turn |
| `attribution` | list of strings | `{ "recorded", "subject", "saved" }` | the rules for which conversation made a commit (see `contents/attribution.info.md`) |
| `title` | string | "How <project> got made" | the table of contents' heading |
| `nav` | function(project) → html, css | — | a strip of links along the top of the table of contents |
| `films` | table | absent: no films | see `films/README.md` |
| `scratch` | string, folder | `tmp/shared-memory/transcript-site` | RAM for working files |
| `evidence_from` | list of strings, folders | none | other transcript folders whose commit lines count: a commit only they record was made from another project's conversation, and is left off the table of contents (issue 040) |
| `hand_made_from` | string, folder | the history folder | the repository a hand-made commit's files are read from; a commit with no conversation and no `Co-Authored-By: Claude` line gets a page of only the lines it added, one turn per file (issue 040) |

Relative paths are read from the project folder.

**To keep a copy inside the project** (so it runs where this repository is
not), pull it:

    pull-transcript-site /path/to/project --without fonts

and call the copy's builder. The copy carries an `UPSTREAM` file naming the
commit it came from. It is never edited in the project: change the library
here, commit, and pull again — whenever the project's dependencies are
updated.

**To put pages of your own around it**, load the builder as a module:

```lua
local site = dofile(project .. "/libs/transcript-site/build-site.lua")
local settings = site.settings.load(project, project .. "/my-settings.lua")
local report = site.build(settings)
site.print_report(report)
-- then write your own pages into settings.output
```

double-diaper-dungeon does exactly this, and writes its age gate, front
page, about page and game pages around the library's.

## What a build says

Conversations written, commits read, groups drawn, how many commits have a
button that lands somewhere and by which rule, films used and messages still
without one, files in the transcripts folder that are not transcripts, and
every fenced code block over 200 lines — listed, never cut. Nothing is ever
redacted; a number that moves is the signal.

## Tests

    luajit tests/test-transcript-site.lua

Builds throwaway repositories under `$TMPDIR` and checks the reader, the page, the
table of contents under both kinds of history and every rule list, the
settings, the films' rules (no model needed), the pull, the push hook, and
that the three parts never load each other.
