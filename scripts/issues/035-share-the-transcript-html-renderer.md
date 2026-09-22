# 035 — Share the Transcript HTML Renderer

| | |
| --- | --- |
| Cluster | transcript system (018–031; see `transcript-system-progress.md`) |
| Blocked by | nothing |
| Blocks | per-project HTML documentation that links into conversations |
| Status | open |

Turns saved conversations into readable web pages for any project, not just
the one that built the renderer.

## Current behavior

A working transcript-to-HTML renderer exists, but only inside
double-diaper-dungeon (`/home/ritz/games/tq/ai-stuff/double-diaper-dungeon`,
its issue 10-003). It is four pieces with one job each:

| piece | job | tied to that project by |
| --- | --- | --- |
| `src/047-transcript-reader.lua` | transcript text in, conversation table out. Opens no files, writes no HTML. | nothing except its hard-coded format expectations |
| `src/050-conversation-page.lua` | one conversation table to one HTML page: speakers on opposite sides, narration shown as narration, model named only where it changes, harness recaps drawn as neither speaker, `id="turn-N"` on every turn | its colours come from the game's balance table through `src/049-site-palette.lua`; hard-coded project root |
| `src/051-commit-timeline.lua` | a landing page that is the commit history, oldest first, with each conversation hung off the run of commits it produced; follows transcript renames through history | reads a separate public "mirror" repository that project builds with `scripts/sync-transcripts-for-github` |
| `src/052-build-site.lua` | joins the three, reports oversized code blocks instead of cutting them, stops on any unreadable transcript | also builds that project's age gate and game pages from `assets/056-games.lua` |

It rests on three libraries vendored from `neocities-modernization`
(`libs/markdown.lua`, `libs/page-head.lua`, `libs/page-template.lua`), and
`markdown.lua` has one deliberate local change: a `reflow` option that joins a
paragraph's wrapped lines before rendering.

**Measured on 2026-09-22:** the reader reads all 5 of that project's transcripts
and all of `/mnt/mtwo/programs/claude-code/llm-transcripts/`, but rejects 28 of
the 32 transcripts in `delta-version/llm-transcripts/` — 27 because they predate
the exporter's models line, and 1 (`FULL-TRANSCRIPT-EXPORT.md`) because it is
not an exporter transcript at all. Many older transcripts cannot be rebuilt
into the new format, because their session logs are gone (see
`rederive-transcripts`, which reports those as frozen). So a shared renderer
has to read the older format too, or every long-lived project's history is
refused.

Nothing in `ai-stuff/scripts/` renders transcripts to HTML. The exporter, the
parser (`libs/conversation-parser.lua`) and the naming rulebook
(`libs/transcript-discovery.sh`) live here; the only reader of the exporter's
*output* format lives in another project on another disk.

## Intended behavior

- One copy of the reader and the page builder, in `ai-stuff/scripts/`, beside
  the exporter whose format they read. A change to the exporter's format and
  the reader that must follow it then sit in the same repository and the same
  commit.
- Any project can build pages for its own `llm-transcripts/` with one command,
  writing into its `tmp/shared-memory/` (RAM), or into `docs/HTML/transcripts/`
  when the project's HTML documentation wants to link into conversations.
- Colours are an argument (a small palette table), not read from any game.
- The commit timeline works from the project's own history when there is no
  mirror; a mirror stays an option for projects that publish one.
- Older transcripts without a models line or a generated-on line are read, with
  the missing facts marked as unknown on the page rather than invented.
  Anything that is not a transcript at all is still refused, loudly.
- double-diaper-dungeon keeps its own gate, pages and palette, and calls the
  shared pieces for the conversation pages and the timeline.

## Suggested implementation steps

1. Copy `047-transcript-reader.lua`, `050-conversation-page.lua`,
   `051-commit-timeline.lua` and the three vendored libraries into
   `ai-stuff/scripts/` (a `transcript-site/` folder, or `libs/` for the
   libraries — decide with the owner), each with its `.info.md`. Keep
   double-diaper-dungeon's tests `048`, `053`, `058` running against the copies.
2. Replace every hard-coded project root with a `set_root`/argument, and the
   balance-table palette with a palette table passed in; ship a default
   palette file beside the renderer.
3. Teach the reader the older transcript shape: accept a missing models line
   and generated-on line, record them as unknown. Add a test over every
   transcript in `delta-version/llm-transcripts/` (the one non-transcript must
   still be refused).
4. Give the timeline a mode that reads the project's own `git log` for
   `llm-transcripts/` instead of a mirror.
5. Add `build-transcript-pages [project-dir] [out-dir]` (house script
   conventions: header, `${DIR}` default overridable by argument, regenerates
   the `tmp/` links before writing).
6. Point double-diaper-dungeon at the shared copy; delete its duplicates in the
   same change so there is one home. Record the move in both projects.
7. Update the transcript-care skill's HTML section and the HTML documentation
   convention in docs to name the command.

## Related documents and tools

- double-diaper-dungeon: `issues/10-003-the-transcript-renderer.md`,
  `issues/10-005-timestamps-for-the-commit-timeline.md` (per-exchange times
  that let a commit link to `#turn-N`), `libs/README-vendored.md`
- `ai-stuff/scripts/issues/transcript-system-progress.md`
- `ai-stuff/scripts/issue-transcript-references` — finds issue-to-transcript
  line links; the pages' `#turn-N` anchors are where such links should
  eventually land
- `~/.claude/skills/transcript-care/SKILL.md`

## Open questions

1. Where does the shared copy live: a `transcript-site/` folder under
   `scripts/`, or split between `scripts/libs/` and a top-level build script?
2. double-diaper-dungeon vendors its libraries so a subscriber's zip runs
   without the monorepo. Does it keep vendored copies of the shared renderer
   too (refreshed by a script), or depend on the monorepo path?
3. Should `markdown.lua`'s `reflow` option go back upstream into
   `neocities-modernization`, so there is one markdown renderer instead of two
   that have diverged?
