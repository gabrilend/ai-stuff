# 040 — Every Commit Finds Its Conversation, or Says Why Not

| | |
| --- | --- |
| Cluster | transcript system (018–039; see `transcript-system-progress.md`) |
| Blocked by | nothing |
| Blocks | nothing |
| Related | 035 (the commit lines this writes are what the table of contents links by); double-diaper-dungeon 10-003a |
| Status | complete, 2026-10-04 |
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

**Built, 2026-10-04, and the measured answer seen.** Double-diaper-dungeon's
story page, built from the rebuilt transcripts against its mirror's
history: **65 commits shown, 65 with a working button** — 63 into
conversations, 2 into pages of her own words (`by-hand-17463e2`,
`by-hand-c7d6693`) — and **5** from the Claude Code folder not shown.
Exactly as step 8 predicted. Commits: ai-stuff `226e7390b` (Parts A and B),
`fe49e4b40` (C and D), `d53d409d7`, `e40ac31d4`, `dedc2c90c` (three fixes
below); double-diaper-dungeon `6c95f84ff`. The whole machine's archive was
rebuilt twice behind a verified snapshot
(`/tmp/transcript-corpus-backup-20261004-172305`), and no transcript on any
of the three disks records a commit twice (2,578 checked).

**What building it taught, beyond the plan:**

- **Real sessions hid announcements in more ways than measured.** Besides
  `tail`: `git commit -q`, which prints nothing; a message file named
  through a variable (`MSG=…; -F "$MSG"`); commit-own-changes' report caught
  in a variable and printed later with a prefix (how `fa4e3a7` was made);
  and git's lower-level `commit-tree`, which prints only the full hash (how
  "Seven stickers…", `bf31081`, was made — not by the Write tool's message
  alone, as first thought). Each is a rule in the parser and a test case.
- **`runs_a_commit` now looks past a step's shell opener** (`do`, `then`,
  `if` …) and a captured `NAME=$(`, or no loop was ever read as a commit.
- **"No double lines" has to know the whole session first.** The first
  build checked only lines already written, and five commits announced by a
  LATER command were written twice; every announced hash is now gathered
  before any line is written (`d53d409d7`, with a test).
- **The archive rebuild missed sessions started through a link.** A session
  started in `/mnt/mtwo/programs/claude-code` (a shortcut to
  `/mnt/mtwo/.claude/claude-code`) is filed under the shortcut's name, and
  `rederive-transcripts` swept only each project's real name: 31 of that
  folder's conversations had never been rebuilt and one never written. The
  rebuild now sweeps every spelling its surviving logs used (`e40ac31d4`,
  `tests/test-rederive-link-spelling.sh`). Across the machine, that folder
  was the only one affected.
- **A session in which nobody spoke** (opening `/config` and closing it) was
  given a transcript with a header and nothing else, which the game's test
  of its transcripts caught. It now hands back no dates, so the exporter's
  husk rule writes nothing and retires the old file (`dedc2c90c`,
  `tests/test_conversation-parser-empty-session.lua`).
- The rebuild's reports count 105 conversations with a commit command that
  matched no single commit — refused commits, mostly, said once and left
  alone, as the rule intends.

What follows is the blueprint as it was written before building.

**How a commit got its button before this.** `libs/conversation-parser.lua`
finds the commits a reply made: `runs_a_commit(command)` says whether a
shell command runs a commit, `commits_reported(msg, commands_by_id)` reads
that command's printed output for git's announcement
(`[main 1a2b3c4] Subject`) or `commit-own-changes`'
(`commit-own-changes: committed 7a29ea7a8 on main in <repo>`), and
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
(ai-stuff commit `7c8c66dd2`): the table of contents read a commit's message
only up to the first line that looked like a file path, so `fa4e3a7`'s
message was cut mid-sentence on the live page, and its `Mirrored-from:` line
below the cut was lost, so the page knew it by the mirror's hash instead of
the game's. Two messages on the live page were cut this way.

New commits are not at risk of A or B: commits now go through
`commit-own-changes`, which prints its announcement whole. C and D can
happen again at any time, by their nature.

## Intended behavior

Four parts, one per row of the table above. The first two make the
exporter write commit lines it missed; the last two settle what the page
does with a commit no conversation of the project made: leave it off, or
give it her own words as its transcript.

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

### Part C — a commit made from another project's conversation is not shown

In the transcript-site library. A project's settings may name **other
transcript folders whose commit lines count as evidence**:

    evidence_from = { "/mnt/mtwo/.claude/claude-code/llm-transcripts" },

- **A commit recorded only there is left off the table of contents.** Her
  decision, 2026-10-04, asked whether such commits should show with a label
  saying where they were made:

  > we should probably just... not display that one, right?

  They are plumbing done to every project at once (rebuilding transcripts,
  re-dating the archive), and a reader of one project's story learns nothing
  from them. Asked whether the page should mention that some are not shown,
  she chose **nothing at all**: no count, no footnote, and the intro's
  "Every commit, oldest first" stays as it is.
- The build's printed report still counts them ("commits made from
  conversations elsewhere, not shown: N"), so the number is seen by whoever
  builds even though no reader sees it.
- A folder in the list that does not exist stops the build, naming it; a
  checkout that lacks it removes the line.
- A monorepo project already reads the rest of its own repository
  (`evidence_elsewhere` in `build-site.lua`, linking to those pages). That
  stays, and those commits stay shown: their pages are part of the site.
  `evidence_from` is for folders outside the repository.

### Part D — a commit made by hand gets her own words as its transcript

In the transcript-site library. Her decision, 2026-10-04:

> the commit message should display just like any other commit. The
> transcript button should link to the file in question, formatted to look
> like a transcript.

1. **Which commits.** `contents/commit-history.lua` records, for each
   commit, whether its message carried an assistant's trailer (`assisted`,
   true when a `Co-Authored-By:` line names Claude), read before the
   trailers are dropped. A commit with no evidence of any kind **and** no
   such trailer was made by hand.
2. **Its row** is drawn exactly as any other commit's: its body (or its
   subject), its date, and a **transcript** button.
3. **The button opens a page of her own words**: `by-hand-<seven>.html`
   beside the conversation pages, drawn by the conversation page as one
   conversation in which she is the only speaker, one turn per file.
   - **Only the lines her commit added**, never the whole file. In
     `docs/020-open-questions.md` her commit added her `->` answers under
     questions an assistant wrote; showing the file whole would put the
     assistant's questions in her mouth. Her rule keeps human and machine
     speech apart, so the page does too.
   - **The heading each block sits under** (the nearest markdown heading
     above it in the file at that commit) is shown as a quiet label above
     the block, not as speech, so a reader knows what she was answering.
   - **Each turn is headed by the file's path**, so a reader knows where the
     words live.
   - **Files under the transcripts folder are left out**: they are the
     conversation export that rode along, not her writing. So are files
     whose added lines are empty or whitespace only.
   - **Only the project's own folder is read.** In a monorepo git names
     paths from the repository's top, so the commit's files are listed
     relative to the project (`--relative`); a sweep touching forty
     projects puts only this project's lines on this project's page, and
     the transcripts-folder rule above sees the project's own folder name.
   - **Only files with text at that commit are read**: a deleted file, a
     submodule (a pointer to another repository's commit) and a binary file
     have none, and are left off. Renames are not followed; the new path is
     an added file. A git read that still fails stops the build with git's
     words, rather than printing "fatal:" and carrying on (2026-11-02: every
     push printed dozens of such lines, and soren-ds's committed disk image
     was read whole to look for headings).
   - The page's title is the commit's subject; its facts line reads
     "written by hand · <date>" in place of the models.
4. **Where the files come from.** The lines are read with
   `git -C <repo> show <commit> -- <path>` from the **project's own
   repository**, not the mirror, using the commit's `source` hash (the
   project commit a mirror commit copies). **This is the one place the site
   reads past the mirror**, the line between public and private that it has
   kept since it was first built; she chose it knowing that, for these
   files only. The setting is `hand_made_from` (a folder, the repository to
   read from; absent means the history folder itself, which is right for a
   project with no mirror). A project that leaves it unset and has a mirror
   gets the commit message alone as the page's one turn.
5. A commit with the trailer and no evidence keeps today's dimmed button
   and "no saved conversation mentions these" — which, once A to C are
   built, should not happen in double-diaper-dungeon at all.

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
   `contents/commit-history.lua`; `evidence_from` and `hand_made_from` in
   `settings.lua` (refusing unknown fields as today); in `build-site.lua`,
   the evidence gathered, commits made elsewhere dropped before grouping,
   and each hand-made commit's added lines read and handed to the
   conversation page as a one-speaker conversation; the facts line's "written
   by hand" in `conversation/conversation-page.lua`. The table of contents
   needs no new row kind: a hand-made commit's button is an ordinary link.
   Tests in `tests/test-transcript-site.lua`: a commit recorded only in an
   `evidence_from` folder is absent from the page and counted in the report;
   a hand-made commit's page holds exactly its added lines, its file paths
   and the headings above them, and not the lines it did not add; a
   transcripts-folder file is left out; the README's settings table.
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
   `evidence_from = { "/mnt/mtwo/.claude/claude-code/llm-transcripts" }` and
   `hand_made_from = ""` (the project itself, whose commits the mirror
   copies). Build, and compare with the build before
   (`scripts/compare-two-sites`). Of the story page's first 70 commits,
   **65 are shown and every one has a working button**: 63 into
   conversations (55, the 3 waiting on the mirror, and A's and B's 5) and 2
   into pages of her own words (`by-hand-17463e2.html`: her lines in
   `desire/what-would-be-better.md`, her answers in
   `docs/020-open-questions.md` under their headings, and
   `notes/monster-ideas`; `by-hand-c7d6693.html`: `new-issue-please-sort`).
   The 5 made from the Claude Code folder are not shown. Its next push
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
