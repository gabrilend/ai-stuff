# Conversation Summary: 5473c7d4-c170-4c2f-a125-44eb0d9926e2

Generated on: 2026-10-21 14:38:49
Models: claude-opus-5-5

## Contents

1. 2026-10-20 13:08, after Request 3 - Goal: let agents reach their own
   project's RAM scratch folders without being asked. The hook is built,
   installed and passing its tests, but uncommitted. Next: you tell me whether
   shell commands on those folders still get stopped.
2. 2026-10-20 13:40, after Request 5 - Goal: keep agents from writing outside
   their own folder, while still letting them use their project's RAM scratch
   folders. Both checks are built, tested and switched on; next, answer the two
   open questions: scratchpad writes, and whether edit tools get refused too.
3. 2026-10-20 14:20, after Request 7 - We're keeping agents' writes inside their
   own project folder, and that check is now live for shell commands and the
   edit tools. Next, I need your go-ahead to give each session a scratchpad in
   the project's RAM folder.
4. 2026-10-21 14:03, after Request 15 - We're stopping agents from writing
   outside their own folder; that's finished and committed, including the new
   "This session" answer. Next, close a session started inside a project that
   has a tmp link, to confirm its scratchpad gets moved.
5. 2026-10-21 14:19, after Request 17 - We're building checks that stop agents
   from writing outside their folder, and now splitting the permission question
   into "how long" and "how wide". Next, you confirm that design, including
   whether "Always + This file" allows only that exact file.

--------------------------------------------------------------------------------

### User Request 1

hi we need to update the hook script that prevents agents from touching files
outside their working directory. First of all it doesn't work, like, at all,
agents are constantly sneaking through using things like sed or stuff. My
understanding is that we only gate the edit tool, right? Anyway it also has
problems whenever we need to access the /tmp/ or /dev/shm/ directory for that
specific project. We should test and see if the project includes links to the
/tmp/ and /dev/shm/ directories, and if so, then we shouldn't complain if they
access that directory. Can you help me implement that?

--------------------------------------------------------------------------------

### Assistant Response 1

I couldn't find a hook that does this. Nothing in your settings stops an agent
from touching files outside its folder. You have three checks that run before
each shell command: one refuses changing directory, one refuses commits that
would carry other sessions' lines, and one refuses git commands that point at a
commit by counting back from the latest one. None of them looks at which file a
command writes to.

What you're seeing is Claude Code's own built-in folder boundary. It explains
both of your problems:

- **Why `sed` gets through:** the built-in boundary is a list of allowed
  folders: the folder the session started in, plus any extra folders. Claude
  Code checks the edit and write tools against that list, and stops to ask when
  one points outside it. A shell command is judged differently. In auto mode a
  classifier reads the command and decides whether it looks safe, and it doesn't
  check the paths against the list. So `sed -i`, `>` redirects, `tee`, `cp` and
  `mv` all slip past. You're right that only the edit tools are gated.
- **Why `/tmp/<project>` and `/dev/shm/<project>` cause trouble:** those folders
  are outside the list, so the edit tools stop to ask, even when the project's
  own `tmp` link points there.

Here's what I'd build, in order of value:

1. **A new check before every tool call that writes,** using the same command
   reader your other three checks use. For a shell command, it would collect
   every path the command writes to: redirect targets, `sed -i`, `tee`,
   `cp`/`mv`/`rm`/`touch`/`mkdir`/`ln`, `install`, and `dd of=`. It would follow
   each path through any links to where it really is, and refuse the command if
   that place is outside the session's folder. The same check would also cover
   the edit and write tools.
2. **The project's RAM folders count as inside.** Starting from the session's
   folder, the check walks up to the nearest folder that has a `tmp` link. If
   that link leads to `/tmp/<name>`, and `/tmp/<name>/shared-memory` leads to
   `/dev/shm/<name>`, both of those folders are treated as part of the project.
   For the edit tools it would actively answer "allow", which also stops the
   built-in boundary from asking about them. A project without the link gets no
   exception.
3. **The same one-time permission file as the other checks** (for example
   `/tmp/claude-allow-outside-write`). It could hold a folder name, which allows
   a write to that folder only.
4. **Your scratchpad folder** (`/tmp/claude-1000/...`) allowed too. Without
   that, sessions can't write their own temporary files.

Two limits to know before we start. The check reads the command's text, so it
can't see writes made inside a script the command runs, or by `lua -e` or
`python -c`. It's the same "honour system with a witness" as the other checks,
not a lock.

Your instructions also call for an issue file in the scripts folder before I
implement, plus test cases added to the existing test runner for these checks.
Two questions:

- **When an agent writes outside its folder, should the check refuse outright,
  or refuse with the one-time permission file as the way through?** I'd
  recommend the permission file, to match the others.
- **Should reads outside the folder stay free?** Agents read the shared
  libraries in `ai-stuff/libs/` and your settings all the time, so I'd only gate
  writes.

--------------------------------------------------------------------------------

### User Request 2

> 2. The project's RAM folders count as inside. Starting from the session's
> folder, the check walks up to the nearest folder that has a tmp link. If that
> link leads to /tmp/<name>, and /tmp/<name>/shared-memory leads to
> /dev/shm/<name>, both of those folders are treated as part of
>      the project. For the edit tools it would actively answer "allow", which also stops the built-in boundary from asking about them. A project without the link gets no exception.

this is what we want

--------------------------------------------------------------------------------

### User Request 3

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

### Assistant Response 3

> Writing the issue file first, then the hook.

> Tests pass (28/28); installing the hook in settings now.

> Updating the README to describe the hook.

I've built and installed the new hook, and all its tests pass. When a session
uses a file tool (read, edit, write, search) on a path inside its own project's
RAM folders, the hook now answers "allow", so Claude Code doesn't stop to ask.
For every other path it stays silent and Claude Code's own folder boundary
decides as before.

**How it decides:**
1. It starts at the folder the session is in and walks up to the nearest folder
   with a `tmp` link. A project without that link gets no exception.
2. It follows that link to `/tmp/<name>`, and the `shared-memory` link inside it
   to `/dev/shm/<name>`.
3. It finds where the requested path really leads, following every link. A file
   that doesn't exist yet is judged by the folder it would be written into. The
   hook answers "allow" only if the path ends up inside one of those two
   folders.

**Safety limits:**
- A `tmp` link pointing at a disk folder, or at `/tmp` itself, opens nothing.
- A link that leads nowhere opens nothing either. That's the state after a
  reboot, until a session starts in the project and the start-up hook rebuilds
  the folders.
- `/tmp/alpha-other` doesn't count as inside `/tmp/alpha`, and another project's
  folders are refused.
- If the hook can't read what Claude Code sends it, it tells you so and gives no
  answer.

**Where it is:**
- The hook is `scripts/allow-own-ram-tiers`. I added a small "allow" helper
  beside the existing "refuse" one in the shared hook library.
- It's installed in `~/.claude/settings.json`, with the old settings kept as
  `settings.json.before-ram-tier-hook`.
- The plan is in `scripts/issues/042-a-project-may-reach-its-own-ram-tiers.md`,
  and `README-refusal-gates.md` now explains the hook.

**Tests:** the new hook's tests pass (28 of 28), and the full test run for all
the hooks passes (204 cases, 0 failures). I also fed it a real request for a log
in the scripts project's RAM folder, and it answered "allow".

I haven't confirmed it working in a live session. This session started at the
monorepo root, which has no `tmp` link, and Claude Code may only load the hook
in sessions started after the change. A quick check: start a session inside
`scripts/` and ask it to read something in `tmp/shared-memory/`.

I haven't committed yet, because the issue still has one open question. Shell
commands are a separate path: Claude Code's auto mode reads each command and
judges whether it looks safe, without checking it against its list of allowed
folders. That's how `sed` slipped through before, and it's also why this hook
can't affect shell commands. Do agents still get stopped when they use a shell
command like `cat` or `tee` on their own `tmp/shared-memory` files, or does the
stopping happen only with the edit and read tools?

--------------------------------------------------------------------------------

### User Request 4

> 1. It starts at the folder the session is in and walks up to the nearest
> folder with a tmp link. A project without that link gets no exception.

this seems like a bug waiting to happen. It should only be in the
project-dir/temp/ directory. Or is it tmp/? I forget. Anyway, that symlinked one
must be in the root of where the agent is running otherwise it needs to ask the
user.

> 2. It follows that link to /tmp/<name>, and the shared-memory link inside it
> to /dev/shm/<name>.

good, and ONLY those two locations.

> - /tmp/alpha-other doesn't count as inside /tmp/alpha, and another project's
> folders are refused.

good

> - The hook is scripts/allow-own-ram-tiers. I added a small "allow" helper
> beside the existing "refuse" one in the shared hook library.

we should make a "harness-hooks" directory that is inside the scripts/ directory
that holds all of these. Can you find all of them and ensure they're properly
moved into there?

You might need to check /home/ritz/.claude/ as well, or
/home/ritz/programs/claude-code/ which I think is a symlink to there.



<pasted_content id="ec7b">
> I haven't committed yet, because the issue still has one open question. Shell
> commands are a separate path: Claude Code's auto mode reads each command and
> judges whether it looks
> safe, without checking it against its list of allowed folders. That's how sed
> slipped through before, and it's also why this hook can't affect shell
> commands. Do agents still get
> stopped when they use a shell command like cat or tee on their own
> tmp/shared-memory files, or does the stopping happen only with the edit and
> read tools?
</pasted_content id="ec7b">


they shouldn't be stopped if they're working on their own files, right?

--------------------------------------------------------------------------------

### Assistant Response 4

> Two changes: the hook will look only at `<session folder>/tmp`, and all hook
> scripts will move into `scripts/harness-hooks/`. Doing the hook change first.

> Moving the seven hook scripts now; settings get updated right after.

> Now fixing references in tests and docs.

> Tests pass after the move (204 + 44), and live hooks are running from the new
> paths. Updating the README and issue.

> Now the issue file.

The hook now checks only the `tmp` link in the folder the agent is running in.
It no longer walks up to parent folders, so if that folder has no link, Claude
Code asks you as before. It allows only the two RAM folders the link leads to:
`/tmp/<name>` and `/dev/shm/<name>`. The folder is `tmp/`, not `temp/`.

**Moved into `scripts/harness-hooks/`:** seven hook scripts. Six are the
existing ones: the three refusal checks, the edit recorder, the start-up
RAM-folder rebuild, and the folder-name carrier. The seventh is the new
RAM-folder hook.
- I moved them with git so their history follows.
- All the hook entries in `~/.claude/settings.json` now point at the new folder.
  This session has been running through them since, with no errors.
- I searched the monorepo, `~/.claude/skills` and `~/programs/claude-code` for
  the old paths. The only references were in five test scripts, and I fixed
  those.
- The full test run for the hooks passes (204 cases, 0 failures), and so does
  the RAM-folder rebuild test (44 passed, 0 failed).

**Left in place:**
- `backup-conversations`: it's a normal command that the end-of-session hook
  also calls. It also has uncommitted edits from another session that aren't
  mine.
- The README, and the shared libraries the hooks load: those stay at
  `scripts/libs/`.
- Official plugins in `~/.claude/plugins` have their own hooks, but none of them
  are enabled.

**Not committed yet:** git can't see the moves as this session's lines, so I'll
need to claim the moved files when we commit.

On shell commands: right, agents shouldn't be stopped when working on their own
files. What I don't know is whether they are being stopped today. In auto mode,
Claude Code doesn't check shell commands against the allowed-folder list at all.
A classifier reads the whole command and decides whether it looks risky. So a
stop on `cat tmp/shared-memory/run.log` would come from the classifier's
judgment, not from the folder rule this hook fixes.

I'd rather not have a hook answer "allow" for shell commands based on the paths
they mention. A command like `lua tmp/tmp/build.lua` only mentions a file in the
project's own RAM folder, but the script it runs can do anything. An "allow"
would skip the classifier's judgment on exactly the commands it's there to
judge.

So the question stays open: when an agent gets stopped working in
`tmp/shared-memory`, which tool was it using? Was it a shell command like `cat`,
`tee` or `>`, or one of the read/edit/write tools? If you can find one stopped
command, even roughly what it looked like, that tells us which of the two
mechanisms is doing the stopping.

--------------------------------------------------------------------------------

### User Request 5

> I'd rather not have a hook answer "allow" for shell commands based on the
> paths they mention. A command like lua tmp/tmp/build.lua only mentions a file
> in the project's own RAM
> folder, but the script it runs can do anything. An "allow" would skip the
> classifier's judgment on exactly the commands it's there to judge.

yes we should design it so that it gets both tests. They should both be allow
for it to succeed.

--------------------------------------------------------------------------------

### Assistant Response 5

> The design: the new check never answers "allow" for a shell command. It can
> only refuse, or stay silent and let the classifier decide, so a command runs
> only when both agree. Writing the issue first.

> The shell reader now keeps redirect targets (50/50 tests pass). Next: a shared
> tier-finding library, then the gate itself.

> Now pointing `allow-own-ram-tiers` at the shared library.

> Shared library in place, hook tests still pass (31/31). Writing the gate.

> Gate written. Now its test file.

> 84/84 pass. Checking how it'd treat this session's own paths before
> installing.

> Live check from this session (a write to `/tmp`, harmless if it got through):

> Refused live. Updating the README and issue.

I built the shell-command check and switched it on, and it's working in live
sessions. It only ever refuses. It never answers "allow", so a command runs only
if both this check and Claude Code's own judgment pass it.

**How it works.** Claude Code's own judgment comes from a classifier: in auto
mode it reads each shell command and decides whether it looks risky. The new
check (`harness-hooks/refuse-outside-writes`) runs before that, on every shell
command:
1. It reads the command the way bash would split it, including commands nested
   inside `bash -c`, `eval` and `$( )`.
2. It finds every place the command writes: redirects like `>`, `>>` and `&>`,
   plus the target files of about 25 commands that write. These include `sed
   -i`, `perl -i`, `tee`, `cp`, `mv`, `rm`, `touch`, `mkdir`, `chmod`, `ln`, `dd
   of=`, `curl -o`, `tar`, `rsync`, and `find -delete`.
3. It follows each path through any links to where it really is.
4. It refuses the command if any of those places is outside the session's
   folder, outside that folder's two RAM folders, and isn't `/dev/null` or one
   of its relatives.
5. If a path contains a variable it can't fill in, it refuses with "cannot tell
   where this points".

If it stays silent, the classifier judges the command exactly as before.

**Your way through:** `! touch /tmp/claude-allow-outside-write` lets one refused
command through, the same as your other checks.

**Supporting changes:**
- The shared command reader used to throw away redirect targets. It now keeps
  them, so the check can read them.
- The rule for finding a project's RAM folders now lives in one shared file,
  used by both this check and the RAM-folder hook, so the two can't drift apart.

**Tests:** 84 cases for the new check pass, and the full test run for the hooks
passes (205, 0 failures). I also tried `echo live-check > /tmp/...` from this
session, and it was refused.

**What it can't see:**
- Anything a script writes after the command starts it.
- `git -C` pointing at another repository.
- Paths fed in through `xargs`.

Both issue files are still open, so nothing is committed yet. Two questions:

1. **The scratchpad folder.** Claude Code gives every session its own scratch
   folder under `/tmp/claude-1000/` and tells the agent to put temporary files
   there. Your house rule says temporary files go in the project's `tmp/`
   instead. Right now the check refuses the scratchpad like any other outside
   folder. Should agents be allowed to write to their own scratchpad, or should
   they be pushed to the project's `tmp/`?

2. **The file tools in auto mode.** When an edit or write tool reaches outside
   the folder, Claude Code asks for permission. Your older directory-change
   check found that in auto mode, that kind of question gets answered
   automatically, without reaching you. If that applies here too, agents can
   also slip out through the edit tools. Should this check also refuse the edit
   and write tools when they point outside the folder and its RAM folders?

--------------------------------------------------------------------------------

### User Request 6

<pasted_content id="ec7b">
> 1. The scratchpad folder. Claude Code gives every session its own scratch
> folder under /tmp/claude-1000/ and tells the agent to put temporary files
> there. Your house rule says
>      temporary files go in the project's tmp/ instead. Right now the check refuses the scratchpad like any other outside folder. Should agents be allowed to write to their own
>      scratchpad, or should they be pushed to the project's tmp/?
</pasted_content id="ec7b">


should be /tmp/project-name/agent-scratchpads/ instead. Then we can allow it.



<pasted_content id="ec7b">
> 2. The file tools in auto mode. When an edit or write tool reaches outside the
> folder, Claude Code asks for permission. Your older directory-change check
> found that in auto mode,
>      that kind of question gets answered automatically, without reaching you. If that applies here too, agents can also slip out through the edit tools. Should this check also refuse
>      the edit and write tools when they point outside the folder and its RAM folders?
</pasted_content id="ec7b">


um....................... yes?

--------------------------------------------------------------------------------

### Assistant Response 6

> Your second answer is a clear yes, so I'm building that now. Moving the
> scratchpad has a design choice in it, which I'll bring back to you.

> 97/97 pass. Installing for the file tools. This is the last settings edit I
> can make without your permission: once it's in, the gate refuses writes to
> `~/.claude`.

> Refused live. Updating the README and issue.

The check now covers the edit and write tools as well as shell commands. When
one of them points outside the session's folder and its RAM folders, it's
refused. Reading outside stays free. I tried a write to `/tmp` live from this
session and it was refused. The new check's tests pass (97, including 13 for the
file tools), and the full test run for the hooks passes (205, 0 failures).

**One thing you'll notice:** the check also refuses writes to `~/.claude/`,
since that's outside every project folder. That includes your `settings.json`,
and plan files if Claude Code saves those there. Changing settings from now on
needs `! touch /tmp/claude-allow-outside-write` first. That was the last
settings change I could make on my own.

**The scratchpad:** `/tmp/<project>/agent-scratchpads/` is inside the project's
RAM folder, so the check already allows it. What's left is getting Claude Code
to put its scratchpad there.
- Claude Code builds the scratchpad path as `<temp
  root>/<project>/<session>/scratchpad`.
- The temp root comes from an environment variable, `CLAUDE_CODE_TMPDIR`. It
  defaults to `/tmp/claude-1000`, and Claude Code needs it to be a private
  folder that only you can open.
- The variable also moves the session's background-task outputs and its internal
  sockets. Claude Code warns when the folder's path is longer than about 30
  characters, because sockets can't sit on long paths.
  `/tmp/kanji-learning-image-generator/agent-scratchpads` is 52, so you'd see
  that warning in some projects.
- It has to be set before Claude Code starts, and differently for each project.

Two ways to set it, best first:

1. **A small `claude` launcher script, ahead of the real program in your PATH.**
   If the folder you start in has a `tmp` link, it creates
   `/tmp/<name>/agent-scratchpads/` (private), sets the variable, and then
   starts the real Claude Code. Your updates to Claude Code stay untouched,
   because the launcher is a separate file.
2. **A setting in each project's own `.claude/settings.json`.** No new script.
   But I don't know whether Claude Code reads that setting before it picks its
   temp folder. I'd have to test it by starting a fresh session.

Which do you want? Nothing is committed yet; both issues stay open until the
scratchpad lands.

--------------------------------------------------------------------------------

### User Request 7

<pasted_content id="ec7b">
> 1. A small claude launcher script, ahead of the real program in your PATH. If
> the folder you start in has a tmp link, it creates
> /tmp/<name>/agent-scratchpads/ (private), sets the
>      variable, and then starts the real Claude Code. Your updates to Claude Code stay untouched, because the launcher is a separate file.
> 2. A setting in each project's own .claude/settings.json. No new script. But I
> don't know whether Claude Code reads that setting before it picks its temp
> folder. I'd have to test it
>      by starting a fresh session.
</pasted_content id="ec7b">


why not build it as part of the hook?

> - The variable also moves the session's background-task outputs and its
> internal sockets. Claude Code warns when the folder's path is longer than
> about 30 characters, because
>     sockets can't sit on long paths. /tmp/kanji-learning-image-generator/agent-scratchpads is 52, so you'd see that warning in some projects.

well we'll have to move it right back when we're done writing to the tmp/
directory. Maybe? This feels complicated.

> - It has to be set before Claude Code starts, and differently for each
> project.

does it? Or can we update it dynamically when we need it?

--------------------------------------------------------------------------------

### Assistant Response 7

A hook can't move Claude Code's own scratchpad. It can do something close enough
that I think it's the better design.

**Why a hook can't move it.** A hook is a child program that Claude Code starts.
On Linux a child gets a copy of its parent's environment variables and can only
change its copy, never the parent's. Claude Code reads `CLAUDE_CODE_TMPDIR`
once, from its own environment when it starts. It works out the scratchpad path,
remembers it, and keeps that answer for the whole session. So nothing that runs
later can change the variable for the running program, whether it's a hook or a
command: Claude Code has already used it and stored the result. The only moment
to set it is before the program starts, which is why I suggested a launcher.

**What a hook can do.** Claude Code gives a hook that runs at session start a
special file (`CLAUDE_ENV_FILE`). Variables written there are set in every shell
command the session runs afterward. Your `carry-working-folder-name` hook
already uses it. Anything a session-start hook prints is also added to the
agent's context. So at session start, a hook could:
1. Create `/tmp/<name>/agent-scratchpads/<session-id>/`, if the session's folder
   has a `tmp` link.
2. Set `TMPDIR` to that folder for the session's shell commands, so `mktemp` and
   most tools put their temp files there without being told.
3. Print one line telling the agent where its scratchpad is.

On top of that, when the write check refuses a write into Claude Code's own
scratchpad (`/tmp/claude-1000/...`), its refusal message would name the agent's
real scratchpad.

**That also settles your "move it back" worry.** Claude Code's own temp folder
never moves. Its sockets and background-task outputs stay at `/tmp/claude-1000`,
so there's no warning about long paths. The agent just gets a different
scratchpad, inside the project's RAM folder where the check already allows
writes.

**One catch.** Claude Code's built-in instructions still tell the agent to use
`/tmp/claude-1000/.../scratchpad`. The first time it tries, the check refuses
and points it to the right folder. After that, the line from the session-start
hook should keep it there. That's one wasted attempt per session at most.

Should I build it this way, as part of the session-start hook? And one question
back: a session started in a folder with no `tmp` link gets no agent scratchpad,
and Claude Code's own scratchpad is refused. Should a session like that be stuck
with nowhere to put temporary files, or should the hook create the `tmp` link
for it?

--------------------------------------------------------------------------------

### User Request 8

why don't we just let the agents write to their default directories, and then
merge their stuff into the correct directory when they finish completely?

--------------------------------------------------------------------------------

### Assistant Response 8

> Yes, that's simpler, and it removes the moving-it-back problem. Here's how I'm
> building it:
>
> - **While the session runs:** the write check allows the session's own Claude
>   Code scratchpad, matched by session ID, so other sessions' scratchpads stay
>   refused.
> - **When the session ends:** a new hook on Claude Code's session-end event
>   moves that scratchpad into `/tmp/<name>/agent-scratchpads/<session-id>/`. If
>   the session's folder has no `tmp` link, the scratchpad stays where it is.

> Now the session-end hook that moves the scratchpad.

> Gate tests pass (103). Now tests for the merge hook.

> Updating issue 043's step 8 and open question.

I've built it the way you described, and all the tests pass. Agents write to
Claude Code's normal scratchpad while they work, and when a session ends, a new
hook moves the files into `/tmp/<project>/agent-scratchpads/<session-id>/`.

**While a session runs:** the write check now allows that session's own
scratchpad. It finds it using the session's ID, which Claude Code sends to every
hook. Another session's scratchpad stays refused, and so does everything else
under `/tmp/claude-1000/`.

**When a session ends:** the new hook (`harness-hooks/merge-agent-scratchpad`)
runs on Claude Code's session-end event:
1. It copies the scratchpad into
   `/tmp/<project>/agent-scratchpads/<session-id>/`.
2. It deletes the original only if the copy worked. If the copy fails, it
   reports the error and the scratchpad is left whole.
3. A resumed session that ends a second time gets merged into the same folder. A
   file with the same name is replaced by the newer one.
4. If the session's folder has no `tmp` link, or the scratchpad is empty, it
   does nothing.

That last point also answers my earlier question about sessions without a link:
they keep their scratchpad where Claude Code put it.

**One gap:** a session that's killed outright never gets the session-end event,
so its scratchpad stays in `/tmp/claude-1000/` until the next reboot clears it.

**Tests:** 16 cases for the new hook and 103 for the write check pass, and the
full test run for the hooks passes (206 cases, 0 failures).

**Not switched on yet.** The session-end hook has to be added to
`~/.claude/settings.json`, and the write check now refuses writes there,
including mine. To let that one edit through, type:

```
! touch /tmp/claude-allow-outside-write
```

Then tell me, and I'll add the hook and commit both issues.

--------------------------------------------------------------------------------

### User Request 9

Hi it seems that when we type this:

  ! touch /tmp/claude-allow-outside-write

we can write to directories using relative paths like this:

● Write(~/.claude/skills/documentation-site/SKILL.md)
  ⎿  Wrote 355 lines to
  ../../../../home/ritz/.claude/skills/documentation-site/SKILL.md

Can you look into that and help guard against relative paths even when
explicitely allowed like that?

--------------------------------------------------------------------------------

### Assistant Response 9

> Now the gate: use the shape check, refuse relative/`~` file-tool paths, and
> never let the permission cover a place it can't pin down.

> 115 and 16 pass. Live check: writing into this session's own scratchpad, which
> used to be refused when the folder didn't exist yet.

> Both behave correctly. Recording the changes in the README and issue.

That write didn't use a relative path. The other session gave its Write tool the
full path, `/home/ritz/.claude/skills/documentation-site/SKILL.md`. Claude Code
always displays paths relative to the folder the session is in, which is where
the `../../../../` came from. The write went through because `! touch
/tmp/claude-allow-outside-write` was typed in that session right after it was
refused. That permission let exactly one write through, and the Edit right after
it was refused again.

I've still added the guard you asked for:

- **Paths the check can't pin down are refused even when a permission is
  waiting.** That covers a relative or `~` path given to an edit or write tool,
  a variable set somewhere outside the command, and `$( )`. The waiting
  permission isn't used up on them, so it stays there for a write whose full
  destination you can see.
- **Bug fix:** that session's log also showed a `mkdir` into its own scratchpad
  being refused. Claude Code only creates the scratchpad folder the first time
  something writes to it, and the check was looking for it on disk. It now
  recognises the session's scratchpad by its path pattern, so the first write
  goes through. I tried both live: a write into this session's scratchpad went
  through, and one into the other session's scratchpad was refused.

The tests pass: 115 for the write check, 16 for the scratchpad move, and the
full test run for the hooks (206 cases, 0 failures).

**A gap that remains:** a permission isn't tied to a session or a place.
Whichever session next hits a refused write uses it up, even one in another
terminal. I could make it work like your directory-change check, where the
permission file can name a folder, for example `! echo /home/ritz/.claude/skills
> /tmp/claude-allow-outside-write`. It would then only let through a write
inside that folder, and expire after ten minutes. Want that?

**Still pending from before:** the session-end hook that moves scratchpads into
the project still isn't switched on. Adding it to `~/.claude/settings.json`
needs one permission from you: `! touch /tmp/claude-allow-outside-write`.
Nothing is committed yet.

--------------------------------------------------------------------------------

### User Request 10

<bash-input>touch /tmp/claude-allow-outside-write</bash-input>

--------------------------------------------------------------------------------

### User Request 11

<bash-stdout>(Bash completed with no
output)</bash-stdout><bash-stderr></bash-stderr>

--------------------------------------------------------------------------------

### Assistant Response 11

> The hook is installed and the permission was used up on that one edit.
> Completing issue 042, which has no open questions left.

> Preparing the commit for issue 042; checking how the preview command takes
> paths.

*[commit] d12fa0f57 in ai-stuff - scripts: a session may reach its own RAM scratch space, and may write nowhere else*

The scratchpad-move hook is now switched on in `~/.claude/settings.json`. Your
one-time permission covered that edit and is now used up. When a session ends,
its scratchpad files move into `/tmp/<project>/agent-scratchpads/<session-id>/`,
if the folder it was running in has a `tmp` link. I haven't seen it run on a
real session ending yet. The first session that closes in a folder with a `tmp`
link will be the real check.

I committed the work as `d12fa0f57`:
- **Done and closed:** the RAM-folder hook for the read and edit tools. That
  plan is now in the completed issues folder.
- **Included, but still open:** the move of all hook scripts into
  `scripts/harness-hooks/` (git records them as renames, so their history
  follows), the shell and file-tool write check, the scratchpad-move hook, and
  the change that makes the command reader keep redirect targets.
- **Left out:** the other uncommitted files in `scripts/` belong to other
  sessions, so they're not in the commit.

The commit message explains why it includes part of the write-check work, which
is still open on one question. Your instructions say to commit only after
closing an issue. That work changed the same files as the finished one, so I
included it rather than leave a commit whose tests pointed at the old hook
locations.

**The one open question:** right now a `! touch /tmp/claude-allow-outside-write`
permission belongs to no particular session and no particular place, so
whichever session next has a write refused uses it up. Should the permission
file be able to name a folder, with only a write inside that folder allowed
through and the permission expiring after ten minutes? That's how your
directory-change check already works.

--------------------------------------------------------------------------------

### User Request 12

also we should ask the user a question with three answers, yes, always, and no.
When we create that file and the llm tries to consume it to perform an edit or
whatever, we should ask if we should allow that file to be on an allowed file
list or whatever. That's the always answer. Yes is "yes, but once."

--------------------------------------------------------------------------------

### Assistant Response 12

> **[Asked the user]**
>
> *Q1 — Ask route:* When a write is refused, how should the yes / always / no
> question reach you?
> - Agent asks, hook reads (Recommended) — The refusal tells the agent to ask
>   you with this same question box, with Yes / Always / No answers. A second
>   hook runs after you answer, reads your answer straight from Claude Code (the
>   agent can't fake it), and writes the one-time permission or adds the file to
>   the allowed list. The agent can't make the permission file itself, because
>   writing to /tmp is already refused.
> - Claude Code's own dialog — The check answers "ask" instead of refusing, so
>   Claude Code shows its built-in Yes / Yes-don't-ask-again / No dialog. Two
>   problems: in auto mode Claude Code's classifier may answer that dialog for
>   you (your directory-change check found this), and its "don't ask again" goes
>   into Claude Code's own rules, not our allowed list.
> → **Selected:** Agent asks, hook reads (Recommended)
>
> *Q2 — Always =:* When you answer Always, what should go on the allowed list?
> - That exact file — Only that one path is allowed from then on, for every
>   session. Writing a new file beside it asks again.
> - The file's folder — Anything inside that folder is allowed from then on.
>   Fewer questions, wider door.
> → **Selected:** The file's folder

> Writing the shared permission store first.

> Now changing the gate to read the allowed list, spend grants, and file
> requests.

> Now the hook that reads your answer.

> Now tests: pointing the gate tests at a scratch permission store, and a test
> for the whole question-and-answer flow.

> 31 flow tests and 115 gate tests pass. Wiring the flow test into the suite and
> writing the docs.

I've built the yes / always / no question, and it passes its tests. It isn't
fully working yet: the hook that reads your answer still needs one line in your
settings.

**How it works:**
1. When an agent tries to write outside its folder, the write check refuses. It
   also files a request in RAM saying which session tried to write where.
2. The refusal hands the agent one exact question to ask you with its question
   box. The question names the places, and its answers are:
   - **Yes:** allow this write, this once.
   - **Always:** allow any write inside that folder, for every session, from now
     on.
   - **No:** keep it refused.
3. A second hook (`harness-hooks/answer-outside-write`) runs after you answer.
   It reads your choice from what Claude Code records, not from the agent.
   - **Yes** lets that session make that one write.
   - **Always** adds the folder to `~/.claude/outside-write-allowed-folders`,
     which every session's write check reads.
   - **No** grants nothing.
   - A request lasts 30 minutes.

**Agents can't fake an answer:**
- If the question was reworded, it grants nothing.
- If the answer comes from a different session than the one that was refused, it
  grants nothing.
- If the agent fills in answers before asking, the question is refused.
- The requests and the allowed list live outside every session's folder, so the
  write check refuses agents writing to them.
- A question that's already been answered can't be answered again.

**Tests:** the new tests for the question and answer pass (31). They cover each
of the cases above, plus a request that has expired. The full test run for the
hooks passes (207 cases, 0 failures).

`! touch /tmp/claude-allow-outside-write` still works as your own way through.
It's yours alone now, since an agent's `touch` in `/tmp` is itself refused.

**Switching it on needs your permission once more.** The hook that reads answers
has to be added to `~/.claude/settings.json`. Until it's there, nothing can read
your answer, so the new question can't grant its own install. Type:

```
! touch /tmp/claude-allow-outside-write
```

and tell me. I'll add the hook, then test it live by trying a write outside this
folder and answering the question for real.

--------------------------------------------------------------------------------

### User Request 13

<bash-input>touch /tmp/claude-allow-outside-write</bash-input>

--------------------------------------------------------------------------------

### User Request 14

<bash-stdout>(Bash completed with no
output)</bash-stdout><bash-stderr></bash-stderr>

--------------------------------------------------------------------------------

### Assistant Response 14

> Refused, with a question to ask. Asking it word for word. Answer **Yes** for
> this test.

> **[Asked the user]**
>
> *Q1 — Outside:* Allow a write outside this session's folder, to
> /mnt/mtwo/.claude/settings.json? [outside-write 9f6257fb]
> - Yes — Allow this write, this once.
> - Always — Allow any write inside /mnt/mtwo/.claude, for every session, from
>   now on.
> - No — Keep it refused.
> → **Selected:** Yes

> The answer hook read your Yes. Running the same edit again:

*[commit] 287c0656c in ai-stuff - scripts: a refused outside write asks the person Yes, Always or No*

> The commit landed. My own `git mv` left a stale staging entry for issue 043,
> and the working file already matches the commit, so I'm clearing that entry.

The yes / always / no question is switched on and worked live. I tried to edit
`~/.claude/settings.json`, which is outside this session's folder, and the write
check refused it and handed me the question. I asked it, you answered Yes, and
the hook read your answer. The same edit then went through once and the grant
was used up, so a second try would be asked again.

Both new settings entries are in place. One checks a question before it's asked
and refuses it if the answers are already filled in. The other reads your answer
afterwards.

Both plans are now closed: the RAM-folder access hook, and the write-check work
(shell and file-tool checks, scratchpad move, yes / always / no). The work is
committed as `d12fa0f57` and `287c0656c`. My earlier `git mv` had left a
leftover entry in git's staging area, and the file already matched the commit,
so I cleared it. The other uncommitted files in `scripts/` belong to other
sessions and weren't touched.

Two things to know:
- **The scratchpad move hasn't run on a real session yet.** It runs when a
  session ends, so the first session you close in a folder with a `tmp` link is
  its real test. After that, `/tmp/<project>/agent-scratchpads/` should hold
  that session's folder.
- **Questions show the path after following links.** `~/.claude` is a link to
  `/mnt/mtwo/.claude`, so the question said `/mnt/mtwo/.claude/settings.json`.
  An "Always" given in such a question allows the `/mnt/mtwo/...` folder, which
  covers the same files.

--------------------------------------------------------------------------------

### User Request 15

okay can we update the yes / always / no to include a fourth option,
"yes-until-end-of-session" or "always temporarily" or something similar?

--------------------------------------------------------------------------------

### Assistant Response 15

> Adding "This session" as a fourth answer, between Yes and Always. It allows
> writes in the same folder Always would, but only until the session ends. The
> question box allows at most four answers, so this fills it. Recording it in
> issue 043 first.

> Now the permission store.

> Now the answer hook and the end-of-session cleanup hook.

> Updating the flow tests for the fourth answer and the cleanup.

> 42 pass. Updating the docs, then installing the cleanup hook.

> Docs updated. Now installing the cleanup hook in settings, which goes through
> the new question.

> **[Asked the user]**
>
> *Q1 — Outside:* Allow a write outside this session's folder, to
> /mnt/mtwo/.claude/settings.json? [outside-write df8bebf2]
> - Yes — Allow this write, this once.
> - This session — Allow any write inside /mnt/mtwo/.claude, for this session
>   only, until it ends.
> - Always — Allow any write inside /mnt/mtwo/.claude, for every session, from
>   now on.
> - No — Keep it refused.
> → **Selected:** Yes

> All passing. Closing issue 043 again and committing.

*[commit] e16934e84 in ai-stuff - scripts: a fourth answer to an outside write, "This session"*

The question now has a fourth answer, **This session**, between Yes and Always.
Four is the most answers the question box allows.

- **What it allows:** writes inside the same folder Always would open, but only
  for the session that was refused, and only until that session ends. Other
  sessions are still refused, and the folder is never added to the every-session
  list.
- **How it ends:** a new hook that runs when a session ends
  (`harness-hooks/forget-session-permits`) removes that permission. It also
  removes any Yes the session never used, so that doesn't carry over either.
  Always stays.
- **One gap:** a session that's killed rather than closed never runs that hook.
  Its This-session permission stays until a reboot clears RAM, or until the
  session is resumed and closed properly.

The new question came up live when I added the end-of-session hook to your
settings. All four answers showed, and your Yes let that one edit through. This
session itself is only covered by tests, not tried live. The tests pass (42 for
the question flow, 207 across all the hooks, 0 failures). I also fixed the line
after the question: it now tells the agent to retry after Yes, This session or
Always, not just Yes or Always.

It's committed as `e16934e84`, and the write-check issue is closed again.

--------------------------------------------------------------------------------

### User Request 16

can we update the "allow a write outside this session's folder" to also have
"yes, for this session only" as well? Any other candidates?

--------------------------------------------------------------------------------

### Assistant Response 16

Three things limit what we can add here:

- **It already exists:** "This session" is a "yes, for this session only". It
  allows writes in that folder until the session ends.
- **The box is full:** the question box takes at most four answers, and we have
  four.
- **"This session" is folder-wide:** it opens the whole folder, not just the one
  file.

So I'm reading your request as one of two things. Either a new label, so it
reads "Yes, for this session only". Or a narrower answer: just this file, for
the rest of the session.

The box does accept up to four separate questions at once. That means the choice
can be split into parts, each with its own answers, instead of packing every
combination into one list. Candidates, most useful first:

1. **Split "how long" from "how wide".** One box with two questions:
   - *How long?* Once, This session, This project, Always.
   - *How wide?* This file, This folder.

   That gives eight combinations, including the one you asked for: this file
   only, for the rest of the session. A "No" on the first question would just be
   a fifth "how long" answer, which doesn't fit, so No would move to the box's
   own "Other" choice or a small first question of its own.
2. **"This project".** Allowed for every session started in the same project
   folder, from now on. It sits between This session and Always. It suits
   outside folders that only one project ever needs, such as a game project
   writing into its server's folder.
3. **A time limit,** such as "for the next hour". It would end on the clock
   instead of when the session ends, so it covers a session that gets killed and
   never runs its end hook.
4. **"Show me first".** The write doesn't happen. The agent shows you what it
   would have written (the edit's text, or the command's target files), then
   asks again. That's for when the path looks fine but you want to see the
   change itself.

Which did you mean by "yes, for this session only": a new label, or this file
only? And do any of these four appeal? The first one would also give your
file-only version.

--------------------------------------------------------------------------------

### User Request 17

> - How long? Once, This session, This project, Always.

how is this project and always not the same thing? Seems similar to me. Can we
remove that one to make room?

--------------------------------------------------------------------------------

### Assistant Response 17

They differ in who gets the permission:

- **Always:** every session on the machine, from any project, may write in that
  folder from now on.
- **This project:** only sessions started in this project's folder may write
  there. A session in another project still gets refused and asked.

So "This project" is a narrower Always. It matters if you run many projects and
one of them needs a folder the others shouldn't touch. If you mostly work in one
monorepo, the two behave the same, and removing it costs little.

With it removed, the box fits exactly:

- **How long?** Once, This session, Always, No
- **How wide?** This file, This folder

That makes six "yes" combinations plus No. Your "yes, for this session only"
becomes *This session + This file*. When the first answer is No, the second is
ignored.

One decision is left: when someone picks **Always + This file**, should only
that exact path be allowed forever, so a new file next to it asks again? That's
the strict choice, and the one I'd pick. Should I build it this way?

--------------------------------------------------------------------------------

### User Request 18

Oh, replace "this project" with "always". That's what always should be, it
should never give global permissions. Can you prune any that already exist and
replace them with project specific permissions? Then we should have room.

--------------------------------------------------------------------------------

### Assistant Response 18

> Two global "Always" entries already exist. Finding which sessions answered
> them, so each can become a permission for that project.

> Both came from sessions in other projects: one in `wow-chat-2026`, one in
> `decomp-client`. I'll rewrite each as a permission for the project that asked.
> Recording the design in issue 043 first.

> Now rewriting the permission store for the two-question design.

> Now the gate's three calls into the store.

> Rewriting the answer hook to read both answers together.

> Rewriting the flow tests for two questions and project-scoped Always.

> 51 pass. Now converting the live lists to the new format. They sit outside
> this folder, so the write check will refuse and ask you, as it should. First,
> reading what's there:

> The new two-question format came up live. Asking it word for word. **Once** is
> the right answer here, since this is a one-time conversion.

> **[Asked the user]**
>
> *Q1 — How long:* Allow a write outside this session's folder, to
> /mnt/mtwo/.claude/outside-write-allowed-folders,
> /dev/shm/claude-outside-writes/session-allowed/bf7987de-b3b0-4fe0-b11e-51f9b6577005,
> /dev/shm/claude-outside-writes/session-allowed/e72751f8-8269-4e4c-b2e2-b2da34b042a7?
> [outside-write 84934fcd]
> - Once — Allow this write, this once.
> - This session — Allow from now until this session ends.
> - Always — Allow from now on, for sessions working in
>   /mnt/mtwo/programming/ai-stuff only.
> - No — Keep it refused.
> → **Selected:** Once
>
> *Q2 — How wide:* If allowed for longer than once, how wide? [outside-write
> 84934fcd width]
> - This file — Only /mnt/mtwo/.claude/outside-write-allowed-folders,
>   /dev/shm/claude-outside-writes/session-allowed/bf7987de-b3b0-4fe0-b11e-51f9b6577005,
>   /dev/shm/claude-outside-writes/session-allowed/e72751f8-8269-4e4c-b2e2-b2da34b042a7.
> - This folder — Anything inside /mnt/mtwo/.claude,
>   /dev/shm/claude-outside-writes/session-allowed.
> → **Selected:** This folder

> Nothing printed means the check stayed silent, so those writes are allowed:
> `jq` prints nothing when given no input. Checking that a project without the
> permission is refused:

> Refused, correctly. Those leftover requests expire on their own after 30
> minutes, so I won't ask you about them. Updating the docs and running the full
> suite.

> All pass. Closing issue 043 and committing.

*[commit] 2029bc0b9 in ai-stuff - scripts: an outside write asks how long and how wide; Always stays in its project*

Always is now limited to one project, and the question is split into "how long"
and "how wide", asked together in one box:

- **How long?** Once, This session, Always, No
- **How wide?** This file, This folder

"Always" now means: from now on, but only for sessions working in the same
project folder as the one that answered. A session in a different project gets
refused and asked again. Your "yes, for this session only" for a single file is
now **This session + This file**. Once covers just the write that was refused,
whatever you pick for width.

**The old global permissions are gone.** Two existed, and I found in the session
logs which project's session had answered each one. Each now holds only for that
project:

| Project that answered | Folder it may write in |
| --- | --- |
| `/mnt/kaun/wow-chat-2026` | `world-edit-to-execute/issues` |
| `/mnt/mtwo/games/azeroth-core/decomp-client` | `/mnt/kaun/custom-client/docs` |

I checked both directions: `wow-chat-2026` may now write in
`world-edit-to-execute/issues`, and `decomp-client` asking for the same folder
is refused.

Two sessions that are running right now also had "This session" permissions. The
new code couldn't read them in their old format, so I converted them as well.
Your **Once** answer to the new two-question box was the permission for that
rewrite, which also tested the new format live.

**Safety checks:** the answer hook grants nothing if either question was
reworded or left out. It also grants nothing if "This session" or "Always" was
picked without choosing a width.

**Tests:** the question-and-answer tests pass (51). They cover each combination,
and check that Always works in one project and not in another. The full test run
for the hooks passes (207 cases, 0 failures).

It's committed as `2029bc0b9`, and the write-check issue is closed again. The
one untracked file left in `scripts/tests/` belongs to another session.

--------------------------------------------------------------------------------

