# build-transcript-pages (and build-site.lua)

Turns a project's `llm-transcripts/` into web pages in
`llm-transcripts/HTML/`.

## Usage

    build-transcript-pages [project-dir] [--palette <file>] [--dir <scripts-dir>]

- `project-dir` — default: the current folder.
- `--palette` — a palette file (see `site-palette.info.md`); default: the
  double-diaper-dungeon colours in `default-palette.lua`.
- `--dir` — where the ai-stuff scripts live.

## What it writes

- `HTML/index.html` — the commit timeline (`commit-timeline.lua`).
- `HTML/<transcript name>.html` — one page per transcript
  (`conversation-page.lua`), named as the transcript is.

## What it reports

Conversations written, commits and runs read; how many commits a transcript
records making, how many are known only by the one transcript they saved,
and how many have no conversation recorded; files in `llm-transcripts/` that
are not transcripts (left alone); and fenced code blocks over 200 lines
(listed, never cut).

## Evidence from the rest of the repository

A project inside a larger repository (the ai-stuff monorepo) also takes
commit records from every other `llm-transcripts/` folder in that
repository, down to three levels: a conversation started at the
repository's top commits to every project in it. Such a commit links to that
project's pages, labelled with where the conversation is filed.

## Rebuilt before every push

`install-pages-hook <repository>...` gives a repository a git `pre-push` hook
that runs `build-pages-before-push`, which rebuilds the pages of every
project in the repository whose transcripts or latest commit are newer than
its front page, and stops the push if one cannot be built (`git push
--no-verify` skips it). The installer also adds `**/llm-transcripts/HTML/`
to the repository's `.gitignore`: the pages are rebuildable output and are
not committed. A pre-push hook some other tool wrote is left alone and
reported — double-diaper-dungeon's rewrites itself to keep its public mirror
in step.

## When it stops

- No `llm-transcripts/` folder, no palette file, or the project is not in a
  git repository (the front page is its history).
- A transcript the reader refuses: the exporter's format moved, and a site
  quietly missing a conversation would look complete.

`build-site.lua` is the Lua program the command runs, taking the project
folder, the output folder and the palette file.
