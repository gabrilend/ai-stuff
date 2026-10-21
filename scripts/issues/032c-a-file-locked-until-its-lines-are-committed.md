# Issue 032c: A File Is Locked Until Its Lines Are Committed

Sub-issue of `032-commit-only-your-own-lines.md`. Builds on
`032a-commit-through-a-private-staging-area.md` (the private commit route)
and `032b-adopt-work-a-finished-session-left-behind.md` (taking over the
lines of a session that ended).

## Origin

The owner, 2026-10-20, in wow-chat-2026, after that project's CLAUDE.md
had been given a hand-kept claims list (`tmp/shared-memory/file-claims`):

> We shouldn't have such a thing, I think, instead we should have a
> utility that can be run like a bash script that asks "is there a lock on
> this file or directory?" and it says yes or no. This should be part of
> the harness, and any file that is modified should be claimed until it is
> git committed, then it is freed again. Essentially, can't modify any file
> that has modifications in the git tree, and we can't commit files that
> aren't changed by us. This somehow needs a way to check and see if the
> agent is still online and working on that file, what possibilities are
> there for the harness to automatically (no LLM involved) respond with a
> "yes" or "no" if the agent is still active in that file? And, if not, can
> we claude -c that file and ask it to make a git commit so someone else
> can resolve their tasks in that file? We will probably need to use a hook
> script for that, right? Also, is there a signal or something that says
> "this session is about to unload it's files from RAM on the server side,
> do you need to make any last minute changes or commits or anything before
> it does?" so that we always shut down cleanly, or go idle with grace?

On the limits of the edit ledger:

> note that if we don't use the edit tool, like if we sed a bunch of text
> into a file, then that doesn't apply. We might even use weird text
> editors and such that allow you to pipe text into them that we haven't
> planned for. There's so many ways to get around that, we should be aware
> that such things are discouraged, yet possible.

On the server side forgetting a session:

> not true! After a certain amount of time, claude-code says that it needs
> to reload your tokens, and it'll cost another 900k tokens or whatever to
> resume your session.

## Current Behavior

- **Who wrote which lines is known only for the edit tools.** The edit
  ledger (`record-own-edits`, a hook run after each tool call) records the
  lines each session adds and removes, in RAM under
  `/dev/shm/claude-own-edits/<session>/`. It sees Edit, Write and
  NotebookEdit, and Bash only when the harness reports a diff for a file
  it was tracking. A file changed by `sed`, a redirect, a script, or an
  editor fed through a pipe is not recorded line by line. The hook names
  such files to the model so it can claim them (`claim-own-change`), but
  nothing makes it.
- **Nothing stops a session editing a file another session has
  uncommitted lines in.** The commit route keeps the two sessions' lines
  apart at commit time (a "mixed" block stops the commit), but the
  collision has already happened by then.
- **Projects coordinate by hand.** wow-chat-2026's CLAUDE.md asks agents
  to write claims into a list and remove them after committing. A list
  kept by the model is only as good as the model's memory of keeping it.
- **Whether a session is alive is not recorded anywhere** a script can
  ask without an LLM.
- **Nothing warns before the server's copy of a conversation lapses.** The
  API keeps a prompt cache: the already-processed conversation, held on
  the server for a fixed time after each use (five minutes or one hour by
  the session's setting). When it lapses, the next turn processes the
  whole conversation again at full price, which in a long session is
  hundreds of thousands of tokens. No hook fires at the lapse.

## Intended Behavior

### A lock is uncommitted lines held by a live session

A file is **locked** when a session that is still alive holds uncommitted
lines in it (its ledger claims lines that differ from HEAD). It is freed
when those lines are committed, or when the session is found gone (below).
There is no separate list to keep: the ledger and git together are the
lock.

A modified file that no live ledger claims is **unclaimed**: a person's
work, a finished session's work (032b's adoption route), or a change made
by a route the ledger cannot see.

### Asking, with no LLM

A command, `is-locked <path>` (a file or a folder), prints one of:

- `free`: no uncommitted changes, or changes held only by the asking
  session.
- `locked by <session> (working | waiting for its person)`: a live
  session holds lines here.
- `held by <session> (gone)`: the session that holds the lines has ended.
- `unclaimed`: changed in git, held by no ledger.

Its exit status says yes or no for scripts; the words say why for people.

### Telling a live session from a gone one

- **At session start** a hook writes the session's id, its process number,
  and that process's start time (the kernel's, from `/proc/<pid>/stat`)
  into a RAM record. Process numbers are reused, so the start time is what
  makes "this process is that session" true.
- **After every tool call** a hook stamps the time ("working").
- **At the end of a turn** (the Stop hook) the record says "waiting for its
  person".
- **At session end** (the SessionEnd hook) the record says "gone".
- **Asking:** the process exists and its start time matches → alive
  (working or waiting, by the last stamp); otherwise → gone. A crash, a
  kill or a reboot fires no hook, which is why the answer comes from the
  kernel and not from the session's goodbye.

### Enforcing it: git's view, not the ledger's

The ledger cannot see every edit, so the lock is judged from **git
status**: a file changed in the working tree may be edited only by the
session that holds it (its ledger claims the change, or it is the
session that last changed the file). Any other changed file is refused,
whether a live session, a gone one, or nobody claims it. The owner,
2026-10-20: "this is why I think we should check the git status
specifically, and disallow any edits that touch files that aren't
claimed or last modified by that session or something."

- **Edit, Write, NotebookEdit:** a hook run before the tool reads the
  path's git status and `is-locked`, and refuses with the holder and its
  state.
- **Shell commands** (`sed`, redirects, piped editors) cannot be read
  for every file they will touch, so they are checked on both sides: a
  hook before the command records which changed files belong to someone
  else; a hook after it compares, and a file that changed under another
  session's lock is reported to the model and the person at once, naming
  the command. Discouraged, not prevented; caught in the same turn, not
  at commit time.
- "Last modified by that session" needs a record per file: the hook
  after each tool call notes, for every file git now shows changed that
  was not changed before the call, that this session changed it. That is
  how a `sed` edit becomes a claim without the model having to say so.

### A gone session's lines

For `held by <session> (gone)`: `claude --resume <session-id> -p "<ask it
to commit its lines in <path>>"` reopens that exact session headless,
which commits through the ordinary route, and the lock is freed. (`claude
-c` resumes the newest session in the folder, which is the wrong one when
several work there.) It is never done to a live session: two processes
would write the same transcript. 032b's adoption is the other way out,
when resuming costs too much or the session cannot be resumed.

### Going idle with grace

- **At the end of each turn**, the Stop hook can keep the session going
  with a message when it holds uncommitted lines older than some age
  ("commit or say why before going idle").
- **Before the prompt cache lapses, the session is woken to commit**
  (owner, 2026-10-20: "yes please, let's wake the session to commit.").
  No hook fires at the lapse, so a timer does it: at each turn's end, if
  the session holds uncommitted lines, a wake is set for the cache's
  lifetime minus a margin; a new turn cancels it. When it fires, the
  session commits what is finished, or writes down why it can't, while
  the cache is still warm and the turn costs little.
  **How (owner, 2026-10-20):** all in a hook script at the end of each
  turn, with Claude Code never told:

  > how about in a hook script we run a timer, and turn off any other
  > timers that have this specific session's label. When the timer
  > expires, we start a new headless session that handles the committing
  > and such, using the same context window as the expiring session.
  > Then, we never have to talk to claude-code about it at all, it
  > wouldn't even notice that anything changed. It's just a hook script
  > at the end of each turn.

  - The Stop hook starts a detached timer labelled with the session id,
    after stopping any earlier timer with the same label. A new prompt
    (the UserPromptSubmit hook) stops it too.
  - What the fork does (owner, 2026-10-20): commits the finished lines
    and the transcripts, leaves uncommitted what is not fit for git, and
    writes down why; **the lock on the committed files is freed**, and
    the lines it left stay locked to the parent session. Any later turn
    of the parent stops the timer and starts it again.
  - When it fires: `FORCE_PROMPT_CACHING_5M=1 claude --resume
    <session-id> --fork-session -p "<commit your finished lines, or
    write down why not>"`. The fork
    reads the same conversation (so the server's warm cache is used, and
    the turn is cheap) but writes its own new session record, so the
    live session's transcript is never written by two processes. The
    live session does not notice; its next turn sees the commit in git.
    The fork commits as itself, so its ledger must be seeded with the
    parent's lines first (032b's adoption, from the parent session).
  - **Being kind to the other side.** The owner, 2026-10-20: "note that
    immediately afterwards, we should clear the server's RAM, so we
    aren't using their resources unnecessarily. Otherwise the claude
    -c'd headless session would persist for another hour. We'd prefer if
    we were kind to our partners on the AI side and instead only used
    the resources we needed, instead of trying to game their systems."
    What is known here: the cache cannot be emptied from this side.
    `/clear` and `/compact` act on the local conversation only (and
    `/compact` sends one more request, to write the summary); the
    server's copy lapses on its own clock, and every request that reads
    it starts that clock again. So the fork's single turn renews the
    hour once. The ways to use less (question 5): a fork that skips the
    cache entirely, as a fresh small session given only the diff, the
    ledger and the issue (no renewal of the big copy, but it lacks the
    conversation's reasons for the commit message); or the fork asking
    for the short cache lifetime instead of the hour, if Claude Code lets
    a session choose.

## Suggested Implementation Steps

1. The session record: a SessionStart hook writing id, process number and
   start time to RAM; PostToolUse, Stop and SessionEnd hooks updating its
   state.
2. `is-locked <path>`, reading the session records, every ledger, and
   `git status` for the path; its four answers and exit status; an
   `.info.md` beside it.
3. The per-file "changed by this session" record, from git status
   before and after each tool call.
4. The PreToolUse refusal for Edit, Write and NotebookEdit, and the
   before-and-after check around shell commands.
5. The wake before the cache lapses, and the Stop-hook nudge for old
   uncommitted lines.
6. A resume helper for gone sessions, refusing a live one.
7. Tests in `test-refusal-gates`: a live session, a waiting one, a killed
   one (no goodbye), a reused process number, a file changed by `sed`.
8. Retire wow-chat-2026's hand-kept claims list from its CLAUDE.md once
   this is in.

## Open Questions

1. (Answered 2026-10-20: "no.") **Folders** are never locked; only files.
   `is-locked <folder>` reports the files inside it that are locked.
2. (Answered 2026-10-20: "No it shouldn't expire.") **A waiting
   session's lock** holds until it commits, however long its person
   takes.
3. (Answered 2026-10-20) **How the wake gets in:** a timer in the Stop
   hook and a forked headless resume (Going idle with grace). **The
   cache's lifetime:** Claude Code does not tell hooks; it is set. Third-
   party pages (not Anthropic's documentation) name two environment
   variables: `ENABLE_PROMPT_CACHING_1H=1` asks for the hour,
   `FORCE_PROMPT_CACHING_5M=1` forces five minutes. Owner: "let's be sure
   to set those variables correctly. The headless commit session can use
   the 5 minute one." So working sessions get the hour (set in
   `~/.claude/settings.json`), the timer is told one hour, and the fork
   runs with the five-minute one.
5. (Answered 2026-10-20) **Fork, then let go of the server's copy.**
   The owner: "fork, but we need to clear the server's cache after we
   finish. We can't make a coherent commit message without the full
   context," and "we should try our hardest to support our hardware
   infrastructure partners." Nothing empties the cache from this side;
   the fork's five-minute setting is the way to use less, **if** a
   five-minute read of an entry written for an hour does not renew it
   for the hour. Still open until tested ("let's test that then"): a
   session written with the hour, a forked five-minute read a minute
   later, then a read past the original hour. A hit on that last read
   means the five-minute read renewed the hour.
   **Tested 2026-10-21**, from the usage figures `claude -p
   --output-format json` reports, in a scratch project
   (`/tmp/ai-stuff-scripts/move-test/cache-project`):
   - With no setting at all, this account's sessions already write the
     one-hour cache (all cache writes counted as one-hour). The
     one-hour variable makes that explicit; it changes nothing today.
   - A forked turn with `FORCE_PROMPT_CACHING_5M=1`, run right after a
     one-hour turn, **read** the parent's cache (about 22,500 tokens
     read, not re-written) and wrote only its own new part (about
     7,700 tokens) with the five-minute lifetime. So the fork is
     cheap (about 4 cents at list price) and still sees the whole
     conversation. The `total_cost_usd` a resumed or forked session
     reports includes the parent's earlier turns, so the fork's own
     cost is the difference from the parent's figure.
   - A third read 62 minutes after the first turn **missed**: the
     conversation was written to the cache afresh (about 23,000 tokens),
     and only the part every session shares was read. So the
     five-minute read did not renew the parent's hour; the parent's
     copy lapsed on its own clock. **Answer: the fork runs with
     `FORCE_PROMPT_CACHING_5M=1`**, and costs the server only its own
     five minutes.
   - `ENABLE_PROMPT_CACHING_1H=1` is now set in `~/.claude/settings.json`
     (2026-10-21, owner: "um, sure, I guess?"), so a change in Claude
     Code's default cannot shorten working sessions' cache unseen. The
     timer is told one hour.
4. (Answered 2026-10-20: "no, if I edit it, I should commit it.")
   **The person's own uncommitted work** is refused to every session,
   with no way to hand it over.
6. (Answered 2026-10-20) **The fork's own transcript** cannot be complete
   in its own commit (the transcript is written when the turn ends, after
   the commit). Its remainder rides along with the next commit.

## Related

- `record-own-edits` (the ledger), `claim-own-change`,
  `commit-own-changes`, `adopt-left-behind-changes`
- wow-chat-2026 `CLAUDE.md`, "When more than one agent works here"
