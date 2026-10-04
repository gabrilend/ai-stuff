# 040 — Recover a Commit Whose Announcement Was Cut Off

| | |
| --- | --- |
| Cluster | transcript system (018–039; see `transcript-system-progress.md`) |
| Blocked by | nothing |
| Blocks | nothing |
| Related | 035 (the commit lines this writes are what the table of contents links by); double-diaper-dungeon 10-003a |
| Status | open — every decision is made below; it needs only building |

The exporter writes a line into a transcript at the moment each commit is
made, and the table of contents on every project's website links a commit by
that line. When a session hid git's own announcement of a commit, no line was
written and the commit's button stays dark. This recovers those commits from
git itself.

Asked for by the owner on 2026-10-04, after finding commits on the game's
story page that "don't seem to reference a transcript":

> let's make the issue file and write it such that it wouldn't require any
> effort on our part when it's implemented.

So this file is meant to be built from top to bottom with nothing to ask.
Everything that needed choosing is chosen, with its reason.

## Current behavior

`libs/conversation-parser.lua` finds the commits a reply made in two
functions. `runs_a_commit(command)` says whether a shell command runs a
commit (its first word is `commit-own-changes`, or is `git` with `commit` as
a later word). `commits_reported(msg, commands_by_id)` then reads that
command's printed output for one of two announcements:

    commit-own-changes: committed 8a235a0fe on main in /mnt/mtwo/.../ai-stuff
    [main 1a2b3c4] Subject of the commit

and `commit_line(commit)` turns each into the transcript's
`*[commit] <hash> - <subject>*` line.

**When the announcement is not in the output, nothing is recorded.** In
September 2026 a session in double-diaper-dungeon committed with
`git ... commit -F $D/msg8.txt -- <paths> 2>&1 | tail -3`. The `tail -3`
kept git's last three lines and dropped the first, `[main ef58f27] A door
at the front, and three rooms behind it`. The commit happened; the log holds
the command, the message file it was written from, and the moment; the
announcement is gone. Claude Code's own structured record of a commit
(`toolUseResult.gitOperation.commit.sha`) is also absent there, because
Claude Code reads it from the same printed line.

Measured on 2026-10-04 with a probe over the game's 35 session logs: of 12
commits on its story page with no line, **4 were made this way** and are
recoverable by the rule below (`24e4962`, `097e0df`, `ef58f27`, `b31bd35`).
The other 8 are not this issue's: 2 were made from the Claude Code program
folder's session, whose transcript records them (`c70f7a9`, `77b69f4`); 2
appear in no session log at all and were most likely made by hand
(`17463e2`, `c7d6693`); and 4 appear in no log under any announcement
(`bf31081`, `cb4b1a5`, `58f89bf`, `ae18f2f`), whose cause is not known and
is not guessed at here.

New commits are not at risk the same way: commits now go through
`commit-own-changes`, which prints its announcement whole. This is for the
archive, and for any session that pipes a commit's output again.

## Intended behavior

**A commit command whose output holds no announcement is checked against
git, and recorded only when git gives exactly one answer.**

1. **Which commands.** Those `runs_a_commit` already accepts, whose output
   (standard output and standard error together) holds neither announcement
   shape. Nothing else is looked at.
2. **The subject, three ways, in this order:**
   - `-F <path>`: the file's first line, taken from the **latest** heredoc
     in the same session, at or before this command, that wrote a file
     with that name (`cat > <anything>/<name> <<'WORD'`, the first line
     after it). The file itself is never read: it lived in a scratch folder
     long gone, and the log is the record.
   - `-F -` with a heredoc in the same command: the heredoc's first line.
   - `-m '<text>'` or `-m "<text>"`: the text's first line.
   A command whose subject cannot be found this way is left alone.
3. **The repository**: the folder after `git -C`, else the log entry's own
   `cwd` field.
4. **The question to git**:
   `git -C <repo> log --all --format='%H %ct %s' --fixed-strings --grep=<subject>`,
   keeping only commits whose subject line is **exactly** the subject and
   whose commit time is from 5 seconds before the command's log timestamp
   to **600 seconds** after. Ten minutes covers a commit hook that runs a
   test suite; the measured cases landed within seconds.
5. **Exactly one, or nothing.** One commit: it is recorded, at the same place
   in the reply the announcement would have been, as an ordinary
   `*[commit] <hash> - <subject>*` line, with the hash abbreviated to nine
   characters. None (the commit was refused, as the game's "The map reaches
   phase ten…" was three times) or more than one: nothing is recorded, and
   the export's report counts it ("commit command with no announcement and
   no single match: N"), because a line that might name the wrong commit is
   worse than no line.
6. **No double lines.** A hash already recorded anywhere in the same
   transcript (the session committed it twice, or the announcement appeared
   in a later command) is not recorded again.
7. **A missing repository or a git that fails** is reported by the export,
   never fatal, and records nothing.

The page side needs no change: the recovered line is the same shape as any
other, so the table of contents links it by the `recorded` rule every
project uses.

## Suggested implementation steps

1. In `libs/conversation-parser.lua`, beside `commits_reported`, add the
   recovery as its own function (`commit_recovered` or so), called only when
   `commits_reported` found nothing for a commit command. Collect heredoc
   message files per session as the log is walked (step 2 above needs the
   latest write before the command).
2. Write `tests/test_conversation-parser-recovered-commits.lua`, building a
   throwaway git repository with a fixed commit time
   (`GIT_COMMITTER_DATE`) and log fixtures, with these cases and answers:
   - `-F file` piped through `tail -3`, the file written earlier by heredoc,
     one matching commit 3 seconds later: **recorded**, nine-character hash.
   - the same with `-F -` and the heredoc in the command: **recorded**.
   - the same with `-m`: **recorded**.
   - the same subject but the commit made 700 seconds later: **nothing**.
   - two commits with the same subject inside the window: **nothing**, and
     counted.
   - a refused commit (no commit with that subject at all): **nothing**.
   - a command that only mentions commit (`git log --grep=commit`):
     **nothing**, as today.
   - the announcement present: recorded **once**, by today's route, not
     twice.
   - a message file written twice under one name: the **later** subject.
3. Run the existing parser tests; all pass unchanged.
4. Take the snapshot (`backup-transcript-corpus`), then
   `rederive-transcripts` (report) and `rederive-transcripts --write`, the
   transcript-care skill's steps 1 to 5, over the whole machine.
5. **Check against the measured answer:** double-diaper-dungeon's
   `llm-transcripts/sep-16-26-through-sep-18-26_agent-1.md` gains commit
   lines for `24e4962`, `097e0df`, `ef58f27` and `b31bd35`, and no others
   are added anywhere in that project. (The probe that measured this is
   described in the Current behavior; rebuild it from that description if a
   second count is wanted.)
6. In double-diaper-dungeon, nothing is done by hand. Its next `git push`
   commits the rebuilt transcripts to the mirror, rebuilds the site and
   publishes it; the story page then links 62 of its first 70 commits: 55
   on 2026-10-04, 3 more from 2 October whose lines were only waiting for
   the mirror to catch up, and these 4. Record that in this issue when seen.
7. Update `transcript-system-progress.md`, move this file to `completed/`,
   commit.

## Related documents and tools

- `libs/conversation-parser.lua` — `runs_a_commit`, `commits_reported`,
  `commit_line`
- `tests/test_conversation-parser-commits.lua` — the existing commit tests,
  the model for the new file
- `rederive-transcripts`, `backup-transcript-corpus` — the rebuild and the
  snapshot before it
- `transcript-site/contents/attribution.lua` — the `recorded` rule that will
  link the recovered lines
- double-diaper-dungeon `issues/completed/10-003a-the-renderer-comes-from-the-shared-library.md`
