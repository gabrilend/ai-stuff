# 035 — Share the Transcript HTML Renderer

| | |
| --- | --- |
| Cluster | transcript system (018–031; see `transcript-system-progress.md`) |
| Blocked by | nothing |
| Blocks | per-project HTML documentation that links into conversations |
| Status | in progress (built and tested; open questions below) |

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
  writing into `llm-transcripts/HTML/` beside the transcripts they are made
  from (decided by the owner 2026-09-26: the double-diaper-dungeon look,
  applied to every project, as part of the transcript system). The exporter,
  the naming rulebook and the sweep all look only at `llm-transcripts/*.md`
  one level deep, so a subfolder of `.html` files is invisible to them.
- The contents list of recaps at the top of a transcript (issue 037) is read,
  shown at the top of the page, and each entry's "after Request N" links to
  that turn's `#turn-N` anchor. Today the reader discards everything above
  the first `###` heading, so the list — and any command line written before
  the first request — is dropped without a word.
- A helper transcript's link from its parent (issue 025) becomes a link to
  the helper's page.
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

## Which conversation made a commit (found 2026-09-26, world-edit-to-execute)

The timeline inherited double-diaper-dungeon's rule: a run of commits
belongs to the conversation whose transcript the run's LAST commit touched,
and when that commit touched several, to whichever came first
alphabetically. That rule was built for that project's public mirror, where
each commit carries exactly its own conversation. Built for
world-edit-to-execute, the owner found it wrong three ways:

- **220 commits (December 2025 to January 2026) hung off a one-turn
  transcript.** Transcripts were not committed alongside work then; the first
  commit to touch any was a bulk import of 297 at once, and the run took the
  first of them, `jan-7-26.md` — a one-shot request from the issue-splitter
  tool, in the old header format (its "Generated on" line is a shell `date`,
  "Tue Dec 30 09:34:56 PM PST 2025").
- **Work hung off a helper.** A commit carries the helper transcripts that
  changed alongside their parent's, and `audit-active-front-issues-...`, a
  read-only audit helper, sorted first.
- **Later bulk re-saves** (archive rebuilds touching every transcript) closed
  runs and named an arbitrary conversation.

The fix is evidence instead of adjacency:

1. **The transcript records the commits its conversation made.** The session
   log holds every command's output, and both commit routes print a
   recognisable line — `commit-own-changes: committed <hash> on <branch> in
   <repository>` (subject on the next line) and plain git's `[<branch>
   <hash>] <subject>`. The parser writes one line into the reply where it
   happened: `*[commit] <hash> in <repository name> - <subject>*`. It is kept
   in the transcript, so it survives the log being deleted, and it tells the
   page which turn made each commit.
2. **The timeline attributes each commit** by, in order: a transcript that
   records making it (matched by hash, or by subject when history was
   rewritten and the hash moved); else a commit that touched exactly one main
   conversation's transcript, helpers counted as their parent (a helper's
   parent is the transcript that links to it); else nobody. Consecutive
   commits with the same conversation form one run. A run with nobody says
   "no conversation is recorded for these" instead of guessing.
3. **A commit known from a transcript links to the turn** where it was made.

## Status on 2026-09-26

Built in `scripts/transcript-site/`, each file with its `.info.md`:

| file | job |
| --- | --- |
| `transcript-reader.lua` | transcript text to conversation table |
| `conversation-page.lua` | one conversation to one page |
| `commit-timeline.lua` | the project's history to the front page |
| `site-palette.lua` | a palette file to CSS colours |
| `build-site.lua` + `build-transcript-pages` | the command: a project's `llm-transcripts/` to `llm-transcripts/HTML/` |
| `default-palette.lua`, made by `make-default-palette` | double-diaper-dungeon's seven page colours, copied from its balance table |
| `archived-exceptions.lua`, made by `find-archived-exceptions` | the old transcripts accepted without a generated-on line |
| `libs/markdown.lua`, `libs/page-head.lua` | copied from double-diaper-dungeon, `reflow` included |
| `tests/test-transcript-site.lua` | 40 checks, including a build of a project inside a larger repository |

What running it against the whole machine taught, and changed:

- **Models write `###` headings in their prose.** The original reader took
  every `###` line as a new turn and refused 38 transcripts across the
  machine (world-edit-to-execute, wow-chat-2026, kanji-learning,
  neocities-modernization), some of them current. A `###` line is now
  structure only directly under the exporter's eighty-dash rule, which a
  model never writes. All 817 transcripts read.
- **No archived exceptions were needed.** The 27 delta-version refusals of
  2026-09-22 were a missing models line, which the exporter itself omits when
  no reply named a model, so the reader now treats it as optional. Every
  transcript has a generated-on line; the generated list is empty, and the
  generator stays as the guard.
- **The contents list and the lines above the first request** were being
  dropped; both are read and drawn now.

Built for the Claude Code program folder (`/mnt/mtwo/.claude/claude-code`):
33 pages, 7 commits, every run linked. Not yet built for any other project.

double-diaper-dungeon keeps its own copies (the two differ, per decision 2);
its `libs/README-vendored.md` lists the differences and points here.
`neocities-modernization/libs/markdown.lua` has a note naming both copies of
the `reflow` change.

## Related documents and tools

- double-diaper-dungeon: `issues/10-003-the-transcript-renderer.md`,
  `issues/10-005-timestamps-for-the-commit-timeline.md` (per-exchange times
  that let a commit link to `#turn-N`), `libs/README-vendored.md`
- `ai-stuff/scripts/issues/transcript-system-progress.md`
- `ai-stuff/scripts/issue-transcript-references` — finds issue-to-transcript
  line links; the pages' `#turn-N` anchors are where such links should
  eventually land
- `~/.claude/skills/transcript-care/SKILL.md`

## Decisions (owner, 2026-09-26)

1. **Home:** a `transcript-site/` folder under `scripts/`, beside the
   exporter, holding the reader, the page builder, the timeline, their
   libraries and a `build-transcript-pages` command.
2. **double-diaper-dungeon:** if its pieces and the shared ones end up the
   same, it uses the shared ones; if they differ, it keeps its own
   standalone copies — that version is known to work — with a note in its
   files pointing at the shared version.
3. **`markdown.lua`'s `reflow` change stays local** for now; not sent back to
   `neocities-modernization`. A note beside each copy names the other.
4. **Older transcripts are a fixed, listed set of exceptions**, not a looser
   reader. The exporter writes the models line into everything it makes now,
   so no new old-shape transcript can appear; the ones that exist are
   archived, their logs gone. The list is generated by a tool that finds
   every transcript the strict reader refuses, and the reader accepts exactly
   those (by session id), marking their missing facts as unknown. Anything
   refused and not on the list is still an error.

### Built the same day

The evidence rules above are built: `libs/conversation-parser.lua` writes
the commit lines (only from a command that ran a commit — the first version
also counted a log search that printed commit reports, and recorded five
commits for a session that had made none), the reader collects them per
turn, and the timeline attributes by them, with a ↗ link from each recorded
commit to its turn. A project inside a larger repository takes commit
records from every transcript folder in that repository. Tests:
`tests/test_conversation-parser-commits.lua` (7 checks) and the attribution,
helper and bulk cases in `transcript-site/tests/test-transcript-site.lua`.

On world-edit-to-execute, after re-exporting its own conversations: 90 of
its 321 commits are recorded by the conversation that made them, and the
other 231 (December 2025 to 22 September 2026) have no evidence — their
session logs are gone, and the transcripts committed then were bulk imports.

Also from the owner's review: each commit title stays on one line (it used
to wrap back under the date and read as a second commit). The pages are not
committed: `install-pages-hook` gives a repository a pre-push hook that
rebuilds stale pages (`build-pages-before-push`) and a `.gitignore` line for
`**/llm-transcripts/HTML/`.

## Open questions

1. **The font.** The pages ask for a shipped monospace font
   (`HackNerdFont-Regular.ttf` and `-Bold.ttf`, 5.3 MB together) in a
   `fonts/` folder beside them. Copying it into every project's
   `llm-transcripts/HTML/` puts 5.3 MB into each repository; not copying it
   means each reader sees their own monospace font (the pages name Hack
   first, so on this machine they look the same if Hack is installed). Not
   copied until decided.
2. ~~Are the pages committed?~~ No (owner, 2026-09-26): rebuildable output,
   ignored by git.
3. ~~When are they rebuilt?~~ Before every push (owner, 2026-09-26), by the
   pre-push hook.
4. ~~Should every project get pages now?~~ Yes, once the review's bugs were
   fixed (owner, 2026-09-26).
