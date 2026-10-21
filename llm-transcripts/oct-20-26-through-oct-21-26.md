# Conversation Summary: e72751f8-8269-4e4c-b2e2-b2da34b042a7

Generated on: 2026-10-21 01:27:59
Models: claude-opus-5-5

## Contents

1. 2026-10-20 13:09, after Request 1 - I've reviewed the file-lock plan, which
   isn't built yet and has five open questions, and how transcripts break when a
   project moves. Next, I need your answers on which transcript copy should
   survive a drive removal, and why each project keeps its own.
2. 2026-10-20 14:06, after Request 2 - We're planning file locks before sessions
   go stale and a safe way to move projects without breaking transcripts.
   Nothing is edited yet, so next I need your yes to record your answers and
   create the project-move issue.
3. 2026-10-20 14:27, after Request 4 - You're having me plan the file lock and
   keep conversation logs whole when projects move; your answers are recorded
   and the move issue is written. Next: type `! touch
   /tmp/claude-allow-outside-write` so I can run the symlink and cache tests.

--------------------------------------------------------------------------------

### User Request 1

Hi, there should be an issue file related to creating a "lock" on directories
and on committing to github when sessions are about to go stale. Can you look
into that for me?

also, we need to examine the ways that the llm-transcripts system handle when we
move directories. What is required for that? Should we leave a symlink behind?
What if we want to remove a drive, that'll break it. It's better if the
llm-transcripts live in one single directory, but how do we make that happen?
Can you look into that for me?

--------------------------------------------------------------------------------

### Assistant Response 1

> I found the lock issue; now I'm checking how the transcript exporter copes
> with a moved project.

## 1. The lock issue

It exists: `scripts/issues/032c-a-file-locked-until-its-lines-are-committed.md`.
It was written and committed today. **It is a plan only. None of it is built
yet.** In short:

- **What a lock is:** a file is locked when it has uncommitted changes and a
  session that is still running made them. `git status` decides which files have
  changes. A check runs before and after each command, so it also sees edits
  made with `sed` or by redirecting output into a file. The lock is released
  when those changes are committed.
- **How it tells whether a session is alive, with no LLM involved:** when a
  session starts, it records its process number and the time the kernel says
  that process started. A process with that number and start time is alive.
  Otherwise the session is gone. This works even after a crash, when the session
  never ran its shutdown step.
- **Sessions about to go stale:** at the end of each turn, a hook starts a timer
  named after that session. If the timer runs out before the server's cached
  copy of the conversation expires, it starts a headless copy of the session
  that commits the finished work.

Five questions are still open, so the issue is in progress:
1. Is a folder locked when any file inside it is locked?
2. Should a lock held by a session that is waiting for you expire after a while?
3. Does Claude Code tell a hook how long the server keeps its cache, or does the
   timer have to be told?
4. How do we release the server's cache once the headless copy has committed?
   Nothing found so far does this from our side.
5. With these rules, your own uncommitted edits block every session. Should you
   be able to hand a file to a session?

## 2. Transcripts when a project moves

There are two layers, and a move affects them differently:

| Layer | Where it lives | What a move does |
|---|---|---|
| Claude Code's raw session logs (the source) | `~/.claude/projects/<the starting path, slashes turned into dashes>/` | **Breaks.** These folders are named after the path, so a moved project gets a new, empty folder and the old history stays under the old name. |
| The readable transcripts | `<project>/llm-transcripts/`, committed with the work | **Fine.** They travel inside the project. |

The wow-chat move shows the break. Two raw-log folders now exist for that
project, one under the old path and one under `/mnt/kaun`. The move copied the
old folder to the new name as hard links. When the exporter catches up on a
project, it reads only one of those two folders, never both.

**Symlinks:** a link left at the old path keeps the old path working. But a
session started through the link files its logs under the link's name, so you
keep two names for one project. When the drive the link points to is removed,
the link points to nothing, and any session started from that path fails. Hard
links can't fix this either, because they can't cross from one drive to another.
When a drive is removed, only a real copy survives.

**One folder for all transcripts, three ways, most promising first:**
1. **Give each project an identity that moves with it.** A small file in the
   project root holds a permanent ID. The exporter writes into one central
   archive filed by that ID, and also copies into the project's
   `llm-transcripts/` so commits still carry them. Moving the project changes
   nothing, because the ID moves with it. Removing a drive takes only the
   project's copy; the central archive stays. The central archive has to sit on
   a drive that never gets removed.
2. **Keep things as they are and teach the move tool to merge the old raw-log
   folder into the new one.** This is the smallest change, but it fixes moves
   only, not drive removal.
3. **Central archive only, with each project's `llm-transcripts/` as a symlink
   to it.** This is the weakest. Git stores the link, not the conversation, so
   commits stop carrying the transcripts, and the link breaks when its drive
   goes away.

I found no existing issue for this. I haven't created or changed any files.

Two questions for you:
- When a drive is removed, which copy should survive, the one in the project or
  the central one? My first option keeps both, but it means every transcript is
  written twice.
- Why does each project need its transcripts inside its own repository: so they
  ride along with each commit, or so the project works on its own on another
  machine? The answer decides whether the central archive is the original and
  the project copy is a duplicate, or the other way round.

--------------------------------------------------------------------------------

### User Request 2

> - Sessions about to go stale: at the end of each turn, a hook starts a timer
> named after that session. If the timer runs out before the server's cached
> copy of the conversation expires, it starts a headless copy of the session
> that commits the finished work.

almost, not quite. If the timer runs out, then that means we need to start a
headless copy and commit the finished work, and leave behind the stuff that we
don't feel comfortable putting on git. Make sure to include the llm-transcripts
from that headless conversation too. If the file is updated again, if there's
another turn or whatever... Then we clear the timer, and restart it.

>   1. Is a folder locked when any file inside it is locked?

no.

> 2. Should a lock held by a session that is waiting for you expire after a
> while?

waiting for me? As in, a prompt I need to address? No it shouldn't expire.

> 3. Does Claude Code tell a hook how long the server keeps its cache, or does
> the timer have to be told?

my understanding was the claude-code doesn't provide that information. We were
using 1 hour because that's what the model's saved information said it was. You
can look online for a better number if you want.

> 4. How do we release the server's cache once the headless copy has committed?
> Nothing found so far does this from our side.

we should try our hardest to support our hardware infrastructure partners.

> 5. With these rules, your own uncommitted edits block every session. Should
> you be able to hand a file to a session?

no, if I edit it, I should commit it.



<pasted_content id="f741">
  ├─────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Claude Code's raw session logs (the source) │ ~/.claude/projects/<the
  starting path, slashes turned into dashes>/ │ Breaks. These folders are
  named after the path, so a moved project gets a new, empty folder and the old
  history stays under the old name. │
  ├─────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
</pasted_content id="f741">


can we, as a matter of course when moving a project directory, rename the old
directory as a symlink to the new one, and merge all the old files into the new
one?



<pasted_content id="f741">
  ├─────────────────────────────────────────────┼─────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ The readable transcripts │ <project>/llm-transcripts/, committed with
  the work │ Fine. They travel inside the project. │
  └─────────────────────────────────────────────┴─────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
</pasted_content id="f741">


ah, but will they be regenerated properly moving forward?

> The wow-chat move shows the break. Two raw-log folders now exist for that
> project, one under the old path and one under /mnt/kaun. The move copied the
> old folder to the new name as hard links. When the exporter catches up on a
> project, it reads only one of those two folders, never
  both.

you say hard link, but it's cross two disks. So separate filesystems. How does
that work? I thought you needed soft links for that.

> Symlinks: a link left at the old path keeps the old path working. But a
> session started through the link files its logs under the link's name, so you
> keep two names for one project. When the drive the link points to is removed,
> the link points to nothing, and any session started
> from that path fails. Hard links can't fix this either, because they can't
> cross from one drive to another. When a drive is removed, only a real copy
> survives.

I think it should be our standard operating procedure to always open new
sessions at the new location, because the old location won't exist anymore.

> 2. Keep things as they are and teach the move tool to merge the old raw-log
> folder into the new one. This is the smallest change, but it fixes moves only,
> not drive removal.

I think we want this one? It has the least complexity.

> - Why does each project need its transcripts inside its own repository: so
> they ride along with each commit, or so the project works on its own on
> another machine? The answer decides whether the central archive is the
> original and the project copy is a duplicate, or the other way
    round.

For the same reason we have git commit messages - so we can understand changes,
and build on top of them.

--------------------------------------------------------------------------------

### Assistant Response 2

## The hard-link question

You're right that hard links can't cross disks, and they didn't have to here.
Claude Code keeps every session log in `~/.claude/projects/`, on `/mnt/mtwo`,
wherever the project itself lives. The folder name `-mnt-kaun-wow-chat-2026`
only spells out the project's path. Both the old-name folder and the new-name
folder sit side by side on the same disk, so the hard links were possible.

Here is what I checked:
- Logs written on Oct 19–20 still show two names per file. Claude Code adds to
  its logs in place instead of replacing them, so the old and new folder names
  see the same file as it grows.
- No log exists only under the old name. For wow-chat, nothing is lost today.

## Will transcripts keep being regenerated properly?

- **After each turn:** yes. The hook uses the log Claude Code points it to and
  writes into the project's own transcript folder. A session started at the new
  location writes to the new place.
- **When rebuilding every old transcript:** only if the raw logs are all under
  the new name. The rebuild reads one raw-log folder and never both. wow-chat is
  complete only because of the hard links.

## Symlink-and-merge as the standard way to move a project

Yes, this works. The steps for each move:
1. Move the project.
2. Leave a symlink at the old path, pointing at the new one.
3. Merge the old raw-log folder into the new-name raw-log folder.
4. Replace the old raw-log folder with a symlink to the new one. Then even a
   session started at the old path by mistake writes its log into the single
   real folder.

Merging can't overwrite anything by accident. Each log file is named after its
session's unique ID, so the same name in both folders means the same session.
Logs only grow, so the longer copy must start with the shorter one. If it
doesn't, the merge stops and reports the mismatch.

If the old drive is removed, its symlink goes with it, and that's harmless
because nothing real lives there.

**One thing I haven't tested:** whether Claude Code will write into a raw-log
folder that is a symlink. I'd test that before relying on step 4.

## Your answers on the lock issue

- **Folders:** not locked.
- **A session waiting on you:** its lock doesn't expire.
- **Your own edits:** you commit them yourself. There is no way to hand a file
  to a session.
- **The timer:** when it runs out, a headless copy of the session commits what
  is fit for git, leaves the rest uncommitted, and includes its own transcript
  in the commit. Any new turn clears the timer and restarts it.

**The headless copy's transcript has a timing problem.** The transcript is
written when a turn ends, and the commit happens inside that turn. So the commit
can include the conversation only up to the point of committing. Two ways out:
- the rest rides along with the next commit, or
- a second, transcript-only commit follows once the turn ends.

Which do you want?

**How long the server keeps the cache:** Claude Code doesn't tell hooks, but it
can be set:
- The setting that asks for the one-hour cache is reported to be
  `ENABLE_PROMPT_CACHING_1H=1`, and `FORCE_PROMPT_CACHING_5M=1` forces five
  minutes
  ([aitmpl](https://www.aitmpl.com/component/mod/observability/prompt-cache-control),
  [claudeissues](https://claudeissues.com/issue/49139-bug-enable-prompt-caching-1h-is-not-working-api-key-user)).
  Those are third-party pages, not Anthropic's own documentation.
- This session's own instructions say it uses the one-hour cache, so one hour is
  right for your sessions.

**Supporting our hardware partners (your fourth answer):** the headless copy
could run with the five-minute setting. Then its single read keeps the server's
copy for five minutes instead of another hour. I haven't verified whether a
five-minute read of an entry cached for an hour actually shortens that entry's
life or simply misses the cache, so it needs a test.

I haven't edited anything yet. Should I:
1. write your answers into the lock issue, and
2. create an issue for the move procedure (symlink, merge, link the raw-log
   folder, and the test of whether a symlinked raw-log folder works)?

--------------------------------------------------------------------------------

### User Request 3

> - After each turn: yes. The hook uses the log Claude Code points it to and
> writes into the project's own transcript folder. A session started at the new
> location writes to the new place.
> - When rebuilding every old transcript: only if the raw logs are all under the
> new name. The rebuild reads one raw-log folder and never both. wow-chat is
> complete only because of the hard links.

sounds like this is a concern.

>   Symlink-and-merge as the standard way to move a project

how is this the standard? Where do we reference this? Should we build a skill
file or something?

> One thing I haven't tested: whether Claude Code will write into a raw-log
> folder that is a symlink. I'd test that before relying on step 4.

we must test this.

> - The timer: when it runs out, a headless copy of the session commits what is
> fit for git, leaves the rest uncommitted, and includes its own transcript in
> the commit. Any new turn clears the timer and restarts it.

and importantly clears the lock on those un-committed files.

> The headless copy's transcript has a timing problem. The transcript is written
> when a turn ends, and the commit happens inside that turn. So the commit can
> include the conversation only up to the point of committing. Two ways out:
>   - the rest rides along with the next commit

this one



<pasted_content id="f741">
> How long the server keeps the cache: Claude Code doesn't tell hooks, but it
> can be set:
  - The setting that asks for the one-hour cache is reported to be
    ENABLE_PROMPT_CACHING_1H=1, and FORCE_PROMPT_CACHING_5M=1 forces five
    minutes (aitmpl
    (https://www.aitmpl.com/component/mod/observability/prompt-cache-control),
    claudeissues
>     (https://claudeissues.com/issue/49139-bug-enable-prompt-caching-1h-is-not-working-api-key-user)). Those are third-party pages, not Anthropic's own documentation.
> - This session's own instructions say it uses the one-hour cache, so one hour
> is right for your sessions.
</pasted_content id="f741">


then let's be sure to set those variables correctly. The headless commit session
can use the 5 minute one.

> Supporting our hardware partners (your fourth answer): the headless copy could
> run with the five-minute setting. Then its single read keeps the server's copy
> for five minutes instead of another hour. I haven't verified whether a
> five-minute read of an entry cached for an hour
> actually shortens that entry's life or simply misses the cache, so it needs a
> test.

let's test that then.

--------------------------------------------------------------------------------

### User Request 4

Base directory for this skill: /home/ritz/.claude/skills/issue-lifecycle

# Issue lifecycle

The owner's CLAUDE.md is the authority on what issue files are for and what
they must contain; where it and this skill ever disagree, CLAUDE.md wins. This
skill adds the mechanics CLAUDE.md leaves open: which tools answer which
question, in what order, and what to do when a tool says no.

All tools live in one place and are called by absolute path:

| Tool | Answers |
|---|---|
| `/home/ritz/programming/ai-stuff/scripts/validate-issues <project>` | is the issue tree consistent; next free number per phase |
| `validate-issues <project> --next <phase>` | the number to give a new issue |
| `validate-issues <project> --file <issue>` | is this one issue well-formed and are its links matched |
| `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m` | done/open counts per phase (for progress files and demos) |
| `/home/ritz/programming/ai-stuff/scripts/commit-own-changes <repo> -F -` | commits exactly the lines this session wrote, plus the changed transcripts of the commit's projects (any conversation's), and runs the repository's commit hooks, without touching the shared staging area |
| `/home/ritz/programming/ai-stuff/scripts/stage-own-changes <repo>` | previews what that commit would take; writes nothing |
| `/home/ritz/programming/ai-stuff/scripts/claim-own-change <file>` | records lines this session changed by a route the edit ledger cannot see (see Committing) |
| `/home/ritz/programming/ai-stuff/scripts/adopt-left-behind-changes <repo> -- <path>...` | takes ownership, line by line, of uncommitted work a finished session left, leaving lines any other session still holds (see Committing) |

Each tool has a `.info.md` beside it; read that rather than the source.

## Before writing a new issue

1. **Search first, including `issues/completed/`.** Grep the issue tree for
   the feature's nouns, not just the likely title. A completed issue about the
   same machinery is reopened and extended rather than duplicated: history is
   more useful stacked vertically in one file than spread across several.
2. **Pick the phase by what the work builds on**, not by when it is being
   done. Lower numbers are foundations; later issues depend on earlier ones.
3. **Take the number from the tool:** `validate-issues <project> --next
   <phase>`.
   It reads the project's own naming shape (522, 1001, 9-007, A04) and never
   reuses a number that a completed file already holds.
4. **Write the blueprint** with the three sections CLAUDE.md requires, plus
   link fields in the shape the project already uses (look at a neighbour).
   Name related functions, structures and files instead of pasting code.
5. **Check it:** `validate-issues <project> --file <new-issue>`, and fix what it
   reports on the new file. If the new issue blocks or is blocked by others,
   add the matching line to the other side too.

## While working

- Keep **Current Behavior** true. It is the only section that changes while
  an issue is in progress; rewrite it in place rather than appending a log.
- A question that surfaces is written into the issue (an "Open questions"
  section) and then asked. An issue with an unanswered question is in
  progress, not done.
- Anything discovered that changes another issue's assumptions is written into
  that issue now, not at completion.

## Splitting into sub-issues

Split when an issue holds work streams that could be built, tested or reviewed
separately, or when it cannot be finished in one sitting. Do not split an issue
that is already one mechanism. When splitting, produce and then write out:

1. **A table** — `| ID | Name | Dependencies | Description |`, where ID is the
   parent number plus a lower-case letter (103a, 103b), Name is dash-separated
   lower-case words, Dependencies is "None" or sibling IDs.
2. **The rationale** — the distinct work streams, why one issue cannot hold
   them, what splitting buys.
3. **The execution order** — a small dependency graph, e.g.
   `103a (foundation) → 103b (needs 103a) → 103c (parallel with 103b)`.

Each row becomes a file `{parent}{letter}-{name}.md` with the three sections.
The parent keeps its blueprint and gains a short list of its sub-issues; the
analysis itself is not appended to the parent (that would be worklog, not
blueprint). Run `validate-issues` afterwards: it reports orphaned sub-issues
and one-sided links.

## Completing an issue

An issue is complete only when nothing in it is deferred and no open question
is unanswered. Then, in this order:

1. **Run the project's tests.** A fixed bug gets a test that would have caught
   it.
2. **Rewrite the issue as the blueprint of what was built**: Current Behavior
   states the built system; steps name the real functions and files; decisions
   not taken are stated with their reason. Poetry the owner wrote during the
   work goes into the issue verbatim.
3. **Move it** into `issues/completed/` (`git mv`, so the history follows).
4. **Update `issues/phase-<N>-progress.md`** for that phase. Take counts from
   `progress-dashboard.lua <project> -m`, or better, name the command instead
   of copying numbers that will go stale.
5. **Update related issues** whose Current Behavior or assumptions changed.
6. **Run `validate-issues <project>`** and fix new findings that the change
   caused. Findings older than the change are reported to the owner, not
   silently fixed in passing.
7. **Commit** as below.

## Committing

The rule (CLAUDE.md): a commit carries exactly the lines this session wrote —
never another session's work, even if it sits in the same file — and every
changed transcript of the commit's projects rides along — the session's own
project folder and the projects of the files it commits — this
conversation's and any other's left behind (a session that committed, talked
on and quit), so each project's story in git stays whole.

Commit small and often: each piece as soon as it is done and checked, not a
pile at the end.

1. Optionally preview: `stage-own-changes <repo>` lists what would be taken
   and what left out, and writes nothing.
2. Commit: `commit-own-changes <repo> -F -` with the message on standard
   input. It builds the commit on a private staging list from this session's
   own lines (the edit ledger the edit hook keeps) plus those transcripts, and
   never touches the shared staging area, so nothing another
   session has staged can ride along. Plain `git commit` is refused by the
   commit gate.
3. Message style: say what the software now does, in plain English and by
   mechanism or analogy; mention any extra changes and why. No function names.

**When it stops or leaves something out.**

- **A tangled ("mixed") block** means another session changed lines right
  next to or on top of yours. Nothing is committed. Tell the owner which file
  and line; decide together what that region should say. `--leave-mixed`
  commits your other blocks meanwhile.
- **Lines that are yours but were written by a route the ledger could not see**
  (a script you ran, a generator, `sed`, a rename): record them with
  `claim-own-change <file>` and say so in the commit message.
- **Nothing to commit, but the work is there**: an earlier session wrote it
  and ended, or the machine rebooted and emptied the ledgers. Look first with
  `adopt-left-behind-changes <repo> --dry-run -- <path>...`, then adopt and
  commit one batch at a time with `commit-own-changes <repo> -F - --
  <path>...`. Lines reported as **held** belong to another session. Take them
  (`--from <session>`) only if that session has finished, and ask the owner
  if unsure. Say in the commit message that the work was adopted and from
  whom. This is the route for a left-behind backlog, not the token.
- **A warning about the shared staging area** means someone had staged that
  file by hand in a way that overlaps your commit; their entry was left alone.
  Tell the owner.

The one-time permission tokens (`/tmp/claude-allow-*`) belong to the person.
Never create one; if a gate names a token, relay the gate's message and let
the owner decide.

## Open questions

- Phase ≥ 10 in compact names depends on the project's issue-number width;
  `validate-issues` decides it from evidence (progress files, `phase-N-demo`
  names). A project with none of those gets a warning. Should the house rule
  fix one width (two digits, as in the 522 example) for every new project?

--------------------------------------------------------------------------------

### Assistant Response 4

> I've written the project-move issue; next I'm writing your answers into the
> lock issue and then running both tests.

Both tests need to write outside this repository: the raw-log folders are in
`~/.claude/projects` (really `/mnt/mtwo/.claude/projects`), and the
outside-writes gate refused my first attempt. I need one permission from you.

**What I'll do with it:** one command that makes a scratch folder in
`/tmp/ai-stuff-scripts/move-test/` and puts one symlink in `~/.claude/projects/`
pointing into that scratch folder.

**What happens next, without further permission:**
1. **Symlink test:** one short headless `claude -p` turn in the scratch project.
   Pass means its log lands inside the symlink's target and the symlink is still
   a symlink.
2. **Cache test:**
   - A turn with the one-hour setting.
   - A minute later, a forked turn with the five-minute setting. Its usage
     numbers show whether it read the cache.
   - A third read about 62 minutes after the first, run in the background. A hit
     means the five-minute read renewed the cache for the full hour.

Each turn re-sends Claude Code's own starting prompt, roughly 20–30k tokens.
Removing the symlink afterwards needs one more permission.

To allow the setup, type:

```
! touch /tmp/claude-allow-outside-write
```

I've recorded your answers in the lock issue, and created the project-move issue
at `scripts/issues/044-moving-a-project-keeps-its-conversations.md`. Neither is
committed yet. That issue now treats symlink-and-merge as the standard way to
move a project, built as one tool in `scripts/`. The move issue has two
questions for you:

1. Do you want a small skill whose only job is to send a session asked to move a
   folder to that tool? Or is a line in CLAUDE.md enough?
2. A project's `.claude/` settings can still name the old path, for example
   saved extra working folders. Should the tool rewrite those, or only report
   them?

--------------------------------------------------------------------------------

### User Request 5

Ah sorry can you try again?

--------------------------------------------------------------------------------

### Assistant Response 5

> **[Asked the user]**
>
> *Q1 — Outside:* Allow a write outside this session's folder, to
> /tmp/ai-stuff-scripts/move-test/project,
> /tmp/ai-stuff-scripts/move-test/log-target,
> /tmp/ai-stuff-scripts/move-test/cache-project,
> /mnt/mtwo/.claude/projects/-tmp-ai-stuff-scripts-move-test-project?
> [outside-write 998aa8d6]
> - Yes — Allow this write, this once.
> - Always — Allow any write inside /tmp/ai-stuff-scripts/move-test,
>   /mnt/mtwo/.claude/projects, for every session, from now on.
> - No — Keep it refused.
> → **Selected:** Yes

> I'm working out why your "Yes" didn't register: the permission hook lost the
> request between the question and your answer.

> **[Asked the user]**
>
> *Q1 — Outside:* Allow a write outside this session's folder, to
> /tmp/ai-stuff-scripts/move-test/project,
> /tmp/ai-stuff-scripts/move-test/log-target,
> /tmp/ai-stuff-scripts/move-test/cache-project,
> /mnt/mtwo/.claude/projects/-tmp-ai-stuff-scripts-move-test-project?
> [outside-write 53c12c90]
> - Yes — Allow this write, this once.
> - Always — Allow any write inside /tmp/ai-stuff-scripts/move-test,
>   /mnt/mtwo/.claude/projects, for every session, from now on.
> - No — Keep it refused.
> → **Selected:** Yes

> **[Asked the user]**
>
> *Q1 — Outside:* Allow a write outside this session's folder, to
> /tmp/ai-stuff-scripts/move-test/project,
> /tmp/ai-stuff-scripts/move-test/log-target,
> /tmp/ai-stuff-scripts/move-test/cache-project,
> /mnt/mtwo/.claude/projects/-tmp-ai-stuff-scripts-move-test-project?
> [outside-write 93a7bbbb]
> - Yes — Allow this write, this once.
> - Always — Allow any write inside /tmp/ai-stuff-scripts/move-test,
>   /mnt/mtwo/.claude/projects, for every session, from now on.
> - No — Keep it refused.
> → **Selected:** Yes

> The symlink test passed. Now the cache test, first turn:

> Now recording the cache findings so far in the lock issue:

The second try worked, and the symlink test passed. The cache test is half done,
and its last read is scheduled for about 02:28.

**Why your earlier "Yes" didn't take:** each permission question expires 30
minutes after the gate asks it. Yours sat for about 3¼ hours (asked at 22:11,
answered at 01:25), so the hook had already thrown it away. Answered within a
few minutes, it worked.

**Symlink test: passed.** I made the scratch project's raw-log folder a symlink
pointing at another folder. One headless turn wrote its log inside the target,
and the symlink was still a symlink afterwards. Claude Code follows the link
instead of replacing it, so "leave a symlink where the old raw-log folder was"
works. A future Claude Code update could change this, so the issue now says the
move tool keeps this as a permanent test.

**Cache test so far:**
- **Your sessions already use the one-hour cache** with neither variable set
  anywhere. Every cache write in the first turn was counted as one-hour. Setting
  `ENABLE_PROMPT_CACHING_1H=1` would only make that explicit.
- **The five-minute headless copy still reads the whole conversation from the
  cache.** About 22,500 tokens were read rather than re-sent. Only its own new
  part, about 7,700 tokens, was written, with the five-minute lifetime. It cost
  $0.22.
- **Still running:** a third read 62 minutes after the first turn. If it finds
  the cache, the five-minute read renewed the one-hour copy. If it doesn't, the
  headless copy only holds server memory for its own five minutes, which is what
  you want. I'll report it when it finishes.

**Written down, not committed:**
- The lock issue (`scripts/issues/032c-…`) now holds all your answers, the
  headless copy's job (commit, release the lock on what it committed, its
  transcript rides with the next commit), and the cache findings.
- The new move issue is
  `scripts/issues/044-moving-a-project-keeps-its-conversations.md`, with the
  symlink result.

**About "how is this the standard?":** right now nothing makes it standard. The
only record is one project's move notes. The new issue proposes a `move-project`
tool in `scripts/`, so the procedure exists in one place.

Three questions:
1. Should sessions find that tool through a small skill, or through one line in
   your CLAUDE.md? A skill is triggered when someone says "move this folder". A
   CLAUDE.md line is read every session whether it's needed or not.
2. Should I add `ENABLE_PROMPT_CACHING_1H=1` to `~/.claude/settings.json`
   anyway? Then a change in Claude Code's default can't silently shorten your
   cache. That file is outside this repository, so it will need another "Yes".
3. When the move tool finds the old path in a project's own `.claude/` settings,
   such as saved extra working folders, should it rewrite them or only list
   them?

Cleaning up the test symlink in `~/.claude/projects` afterwards will need one
more "Yes".

--------------------------------------------------------------------------------

