# 040 — Every Commit Finds Its Conversation, or Says Why Not

| | |
| --- | --- |
| Cluster | transcript system (018–039; see `transcript-system-progress.md`) |
| Blocked by | nothing |
| Blocks | nothing |
| Related | 035 (the commit lines this writes are what the table of contents links by); double-diaper-dungeon 10-003a |
| Status | open — every decision is made below; it needs only building |
| Was | `040-recover-a-commit-whose-announcement-was-cut-off.md`, renamed the same day when its scope grew |

On every project's website, the table of contents gives each commit a
button into the conversation that made it. Some commits get a dark button
and no explanation. This finds the conversation behind every such commit
that has one, and for the rest, says on the page why there is none.

Asked for by the owner on 2026-10-04:

> let's make the issue file and write it such that it wouldn't require any
> effort on our part when it's implemented.

and, when the first version of this file covered only some of the commits:

> so wait wasn't the entire point that we'd be able to find those? Why can't
> it help with that?

So this file covers every unlinked commit on double-diaper-dungeon's story
page, and is meant to be built from top to bottom with nothing to ask.

## Current behavior

**How a commit gets its button today.** `libs/conversation-parser.lua`
finds the commits a reply made: `runs_a_commit(command)` says whether a
shell command runs a commit, `commits_reported(msg, commands_by_id)` reads
that command's printed output for git's announcement
(`[main 1a2b3c4] Subject`) or `commit-own-changes`'
(`commit-own-changes: committed 8a235a0fe on main in <repo>`), and
`commit_line(commit)` writes `*[commit] <hash> - <subject>*` into the
transcript. The site's table of contents (`transcript-site/contents/`) links
a commit by that line. No line: a dimmed button, and the heading "no saved
conversation mentions these".

**Measured on 2026-10-04**, double-diaper-dungeon's story page had 15 of
its 70 commits unlinked. 3 were from 2 October and only waiting for the
public mirror to catch up on the next push. Probes over every session log on
the machine (`~/.claude/projects/`) found what happened to each of the other
12. Four different things:

| | commits (the game's hashes) | what happened |
| --- | --- | --- |
| A | `24e4962`, `097e0df`, `ef58f27`, `b31bd35` | A game session committed with `git … commit -F $D/msgN.txt … 2>&1 \| tail -3`. The `tail` kept git's last lines and dropped the first, the announcement. The message file was written earlier in the session by a heredoc. |
| B | `bf31081` ("Seven stickers…") | The same, except the message file was written with the **Write tool**, not a heredoc, at 03:29 UTC; the commit landed at 03:29:38. |
| C | `c70f7a9`, `77b69f4`, `cb4b1a5`, `58f89bf`, `fa4e3a7` | Made from conversations in the **Claude Code program folder** (`/mnt/mtwo/.claude/claude-code`, sessions `0f60e49a…`, `4b7b1ff4…`, `35463463…`), which committed the same change into many projects at once. Two (`c70f7a9`, `77b69f4`) are announced and recorded in that folder's transcript `sep-16-26.md`. The other three were made by a loop (`while read R; do git -C "$R" commit -F <file> …`) whose output showed no announcement, so they are recorded nowhere. |
| D | `17463e2` ("human written notes"), `c7d6693` ("I wrote an issue file…") | **Made by her, by hand**, from her own terminal: no session ran a commit near those times, and neither message carries a `Co-Authored-By:` line, which every commit a session makes does. Only 6 of the game's commits lack that line. |

A fifth problem turned up while measuring, and is **already fixed**
(ai-stuff commit `99c9c63ff`): the table of contents read a commit's message
only up to the first line that looked like a file path, so `fa4e3a7`'s
message was cut mid-sentence on the live page, and its `Mirrored-from:` line
below the cut was lost, so the page knew it by the mirror's hash instead of
the game's. Two messages on the live page were cut this way.

New commits are not at risk of A or B: commits now go through
`commit-own-changes`, which prints its announcement whole. C and D can
happen again at any time, by their nature.

## Intended behavior

Four parts, one per row of the table above. The first two make the
exporter write commit lines it missed; the last two make the page say
something true about a commit no conversation of the project made.

### Part A — a commit command whose announcement is missing

In `libs/conversation-parser.lua`. A command `runs_a_commit` accepts, whose
output (standard output and standard error together) holds neither
announcement shape, is checked against git, and recorded only when git gives
exactly one answer.

1. **The subject**, in this order:
   - `-F <path>`: the first line of the **latest** write, at or before this
     command in the same session, of a file with that base name — a heredoc
     (`cat > <anything>/<name> <<'WORD'`, the line after it) **or a Write
     tool call** (`file_path` ending in `/<name>`, the first line of its
     `content`). The file itself is never read; it lived in a scratch folder
     long gone.
   - `-F -` with a heredoc in the same command: the heredoc's first line.
   - `-m '<text>'` or `-m "<text>"`: the text's first line.
   No subject found: left alone.
2. **The repository**: the folder after `git -C`, when it is a literal path;
   else the log entry's own `cwd`. When `-C` names a shell variable (a loop),
   the repository cannot be read from the command: that is Part B.
3. **The question**:
   `git -C <repo> log --all --format='%H %ct %s' --fixed-strings --grep=<subject>`,
   keeping commits whose subject is **exactly** the subject and whose commit
   time is from 5 seconds before the command's timestamp to **600 seconds**
   after. Ten minutes covers a commit hook running a test suite; every
   measured case landed within a minute.
4. **Exactly one, or nothing.** One: recorded, where the announcement would
   have been, as an ordinary `*[commit] <hash> - <subject>*` line, hash
   abbreviated to nine characters. None (a refused commit — the game's "The
   map reaches phase ten…" was tried three times and refused every time) or
   more than one: nothing, and the export's report counts it ("commit command
   with no announcement and no single match: N").
5. **No double lines**: a hash already recorded in the same transcript is
   not recorded again.
6. A missing repository or a failing git: reported, never fatal, nothing
   recorded.

### Part B — a loop that commits into many repositories

Same file. A command that `runs_a_commit`, has no announcement, and names
its repository through a variable (`-C "$R"`, `-C $R`, `cd "$R"`), with its
subject found as in Part A:

1. **Where to look**: every repository holding an `llm-transcripts/`
   folder, found the way `rederive-transcripts` finds projects (its
   `SEARCH_ROOTS`, its depth), each repository once.
2. **The question**, in each: Part A's, same window.
3. **One per repository, or none there.** Every repository with exactly one
   match gets a line, `*[commit] <hash> in <repository name> - <subject>*`
   (the shape `commit-own-changes` lines already use). A repository with two
   matches gets none, and is counted.
4. The lines go into the transcript of the session that ran the loop —
   which is where the conversation that made those commits lives.

### Part C — a commit made from another project's conversation

In the transcript-site library. A project's settings may name **other
transcript folders whose commit lines count as evidence**:

    evidence_from = { "/mnt/mtwo/.claude/claude-code/llm-transcripts" },

- A commit recorded only there gets no link (that conversation is not on
  this site), and its row and group heading say where it was made:
  **"made from a conversation in claude-code, not published here"**, the
  folder's project name taken from its path.
- A folder in the list that does not exist stops the build, naming it; a
  checkout that lacks it removes the line.
- A monorepo project already reads the rest of its own repository this way
  (`evidence_elsewhere` in `build-site.lua`, linking to those pages). That
  stays. `evidence_from` is for folders outside the repository, whose pages
  are not part of the site.

### Part D — a commit made by hand

In the transcript-site library. `contents/commit-history.lua` records, for
each commit, whether its message carried an assistant's trailer
(`assisted`, true when a `Co-Authored-By:` line names Claude), read before
the trailers are dropped. A commit with no evidence of any kind **and** no
such trailer is drawn as **"made by hand, outside any conversation"**, in
the dimmed button's place, with the same quiet style. A commit with the
trailer and no evidence keeps today's dimmed button and "no saved
conversation mentions these" — which, once A to C are built, should not
happen in double-diaper-dungeon at all.

The rows' words are settings with these defaults, so another project can
say them its own way: `made_elsewhere_label`, `made_by_hand_label`.

## Suggested implementation steps

1. **Part A** in `libs/conversation-parser.lua`: a function beside
   `commits_reported`, called only when it found nothing for a commit
   command; collect heredoc and Write-tool file writes per session as the
   log is walked.
2. **Part B** beside it, sharing the subject and the question.
3. Write `tests/test_conversation-parser-recovered-commits.lua`, with
   throwaway repositories at fixed commit times (`GIT_COMMITTER_DATE`) and
   log fixtures, these cases and answers:
   - `-F file`, heredoc written earlier, output through `tail -3`, one
     match 3 s later: **recorded**, nine-character hash.
   - `-F file` written by a Write tool call: **recorded**.
   - `-F -` with the heredoc in the command: **recorded**. `-m`: **recorded**.
   - the match 700 s later: **nothing**. Two matches: **nothing**, counted.
   - a refused commit (no match): **nothing**.
   - `git log --grep=commit`: **nothing**, as today.
   - the announcement present: recorded **once**, by today's route.
   - a message file written twice under one name: the **later** subject.
   - a loop over three repositories, `-C "$R"`, matches in two: **two
     lines**, each naming its repository; nothing for the third.
4. Run the existing parser tests; all pass unchanged.
5. **Parts C and D** in `transcript-site/`: `assisted` in
   `contents/commit-history.lua`; `evidence_from`, `made_elsewhere_label`
   and `made_by_hand_label` in `settings.lua` (refusing unknown fields as
   today); the evidence gathered in `build-site.lua`; the two new row and
   heading kinds in `contents/contents-page.lua`, each drawn only when it
   happens, so a page with neither is unchanged. Tests in
   `tests/test-transcript-site.lua` for each, and the README's settings
   table.
6. Snapshot (`backup-transcript-corpus`), then `rederive-transcripts`
   (report) and `rederive-transcripts --write`, over the whole machine, as
   the transcript-care skill's steps 1 to 5.
7. **Check against the measured answer.** In double-diaper-dungeon's
   transcripts, `sep-16-26-through-sep-18-26_agent-1.md` gains lines for
   `24e4962`, `097e0df`, `ef58f27`, `b31bd35`, and `sep-16-26.md` for
   `bf31081`; nothing else there gains one. The Claude Code folder's
   transcripts gain lines, each naming double-diaper-dungeon, for
   `cb4b1a5`, `58f89bf` and `fa4e3a7` (and lines for the same loops'
   commits in the other projects they touched).
8. **In double-diaper-dungeon**, pull the library
   (`scripts/pull-transcript-site`), and add to
   `assets/070-transcript-site-settings.lua`:
   `evidence_from = { "/mnt/mtwo/.claude/claude-code/llm-transcripts" }`.
   Build, and compare with the build before (`scripts/compare-two-sites`).
   The story page's first 70 commits should read: **63 linked** (55, the 3
   waiting on the mirror, and A's and B's 5), **5 "made from a conversation
   in claude-code"**, **2 "made by hand"**, **0** unexplained. Its next push
   publishes it; nothing else is done by hand.
9. Record the counts seen in this file, update
   `transcript-system-progress.md`, move this file to `completed/`, commit.

## Related documents and tools

- `libs/conversation-parser.lua` — `runs_a_commit`, `commits_reported`,
  `commit_line`
- `tests/test_conversation-parser-commits.lua` — the model for the new test
- `rederive-transcripts`, `backup-transcript-corpus` — the rebuild, and the
  snapshot before it
- `transcript-site/contents/commit-history.lua`, `attribution.lua`,
  `contents-page.lua`, `transcript-site/settings.lua`, `build-site.lua`
- double-diaper-dungeon `assets/070-transcript-site-settings.lua`,
  `scripts/compare-two-sites`,
  `issues/completed/10-003a-the-renderer-comes-from-the-shared-library.md`
