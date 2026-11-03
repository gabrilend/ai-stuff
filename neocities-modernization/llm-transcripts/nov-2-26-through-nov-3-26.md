# Conversation Summary: 844daecf-7be6-4b4f-bae3-423139ef88d7

Generated on: 2026-11-03 11:26:14
Models: claude-opus-5-5

## Contents

1. 2026-11-02 18:45, after Request 11 - You're rebuilding the site, and the
   error came from a typo: "wordcloud-poems" needs two leading dashes. Rerun
   with that fixed, then deploy with the prune option and check a page on your
   phone.
2. 2026-11-02 19:43, after Request 14 - You're rebuilding the neocities site,
   and I fixed the picture-fingerprint error that stopped it; the tests and your
   701 pictures all pass. Next, restart the build, and tell me whether to commit
   the fix.
3. 2026-11-03 10:10, after Request 22 - The deploy is ready to finish now that
   the download is split into 90 MB pieces. Next, run
   ./scripts/deploy-to-neocities --prune, and tell me if it stops on one of the
   pieces.
4. 2026-11-03 11:19, after Request 24 - The goal is a working Neocities deploy,
   and the download is now fixed so plain zip and unzip open it. Next, run
   ./scripts/deploy-to-neocities --prune, then tell me if I can commit both
   changes together.

--------------------------------------------------------------------------------

### User Request 1

Hi I was wondering if you could tell me where this project is at with the next
deployment? Is there anything that's critical we need to do before we
re-compile? I'm going to do it anyway, but let me know if you can find anything.

I get this error when I run the script:



<pasted_content id="e071">
$ ./run.sh --full --threads 4 --poems-per-page 64 --wordcloud-words all
wordcloud-poems 64 --chrono-per-page 64 --boosts yes --force --verbose --server
local --model embeddinggemma-2
Error: stage-timing library not found: 64/scripts/stage-timing.sh
       It records each stage's wall-clock time to .stage-timings, which
       the pre-flight plan reads back as its duration estimates.
</pasted_content id="e071">

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 2

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 3

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 4

please continue

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 5

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 6

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 7

please continue

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 8

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 9

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 10

Your claude.ai usage limit has reset. Continue the task you were working on when
the limit was reached; do not repeat work that is already complete.

--------------------------------------------------------------------------------

*You've hit your session limit · resets 6:20pm (America/Los_Angeles)*

--------------------------------------------------------------------------------

### User Request 11

please continue

--------------------------------------------------------------------------------

### Assistant Response 11

> Still checking whether the last session left anything that has to happen
> before a rebuild.

The error comes from a typo in your command. `wordcloud-poems 64` is missing its
two leading dashes.

**What happened:** the script reads any word without dashes as the project
folder path. `wordcloud-poems` became the folder, and then `64` replaced it, so
the script looked for its timing library in a folder called `64/scripts/`.
Corrected command:

```
./run.sh --full --threads 4 --poems-per-page 64 --wordcloud-words all --wordcloud-poems 64 --chrono-per-page 64 --boosts yes --force --verbose --server local --model embeddinggemma-2
```

**Nothing critical blocks the rebuild.** I checked a few things:
- **Files:** this project has no uncommitted changes except the new screenshot
  history folder (`development-history/`), which hasn't been committed yet. That
  doesn't affect the build.
- **Building the site in RAM:** the one-time move has already been done.
  `output/` now points into RAM (`tmp/shared-memory/site`). One consequence: a
  reboot erases the built site until the next build.
- **Work still open:** the memory-budget splitting and running every batch step
  in parallel are both unfinished, but neither stops a build.

**After the build, from the last session's notes:**
1. **Deploy with `scripts/deploy-to-neocities --prune`.** Some page names
   changed and some retired pages were dropped, and `--prune` removes the old
   ones from Neocities.
2. **Check a page on a phone.** Open one poem page and one source-browser page
   on a real phone, or in Firefox's responsive mode. Confirm the background is
   one single black and the text fits the width. That is the last step for both
   the pure-black issue and the monospace-font issue.

**Open question:** the script accepts several bare words and quietly keeps only
the last one. That's why the typo gave a confusing error about a missing library
instead of saying "unexpected word: wordcloud-poems". Do you want a second bare
word to stop the run with an error that names it? I haven't changed anything.

--------------------------------------------------------------------------------

### User Request 12

<pasted_content id="e071">
================================================================
Generation completed at: Mon Nov  2 06:53:45 PM PST 2026
================================================================
   Embedding pictures by what they show...
[pictures] 1200 pictures to place; fingerprinting...
luajit: ...stuff/neocities-modernization/src/picture-embeddings.lua:142:
picture-embeddings: could not fingerprint
/mnt/mtwo/programming/ai-stuff/neocities-modernization/input/images/dnd-pictures/0vk4u1bcj03e1.png
stack traceback:
        [C]: in function 'error'
        ...stuff/neocities-modernization/src/picture-embeddings.lua:142: in function 'fingerprints'
        ...stuff/neocities-modernization/src/picture-embeddings.lua:312: in function <...stuff/neocities-modernization/src/picture-embeddings.lua:263>
        [C]: in function 'xpcall'
        ...ramming/ai-stuff/neocities-modernization/libs/output.lua:104: in function 'guard'
        ...stuff/neocities-modernization/src/picture-embeddings.lua:334: in main chunk
        [C]: at 0x55ef37d9a370
stack traceback:
        [C]: in function 'error'
        ...ramming/ai-stuff/neocities-modernization/libs/output.lua:107: in function 'guard'
        ...stuff/neocities-modernization/src/picture-embeddings.lua:334: in main chunk
        [C]: at 0x55ef37d9a370
Error: picture embedding failed
       Pictures are placed among the poems by these vectors;
       Stage 6.7 cannot place a picture that has none.
Shutting down inference server (PID 30974) that this run started...
</pasted_content id="e071">

--------------------------------------------------------------------------------

### Assistant Response 12

I found the cause. The picture it names is fine: it exists, it's readable, and
it fingerprints cleanly when done alone. The bug is in how the fingerprints are
gathered when many processes run at once.

**How it breaks:** the build hands the picture list to 16 copies of the
fingerprint program (`md5sum`) running at the same time. All of them write their
answers into one shared pipe. Each copy saves up about 4 KB of answers and then
writes it out in one piece. A 4 KB piece usually ends partway through an answer,
and another copy's piece can land in the gap. That answer is then split in two
and can't be read. The pipeline then reports the first picture with no answer.
It names a real file, but that file was never the problem.

**Reproduced:** I ran the same command five times on your 701 input pictures.
The number of readable answers was 690, 690, 692, 693 and 693. That's 8 to 11
lost per run, and a different set each time. So rerunning the build will fail
the same way.

**Proposed fix:** each group of 64 pictures writes its answers to its own small
file in the RAM scratch folder, and the program reads those files once every
group has finished. This keeps all the processors busy, and answers can no
longer mix. Two extras:
- If any fingerprint program fails, the run stops with an error that says so.
  Right now a failure is invisible.
- A test that fingerprints a few hundred files several times and requires every
  one to come back every time.

I haven't changed anything. Do you want me to make this fix now so you can
restart the build?

--------------------------------------------------------------------------------

### User Request 13

also my computer tells me there's a luajit process running, can you look into
that

--------------------------------------------------------------------------------

### Assistant Response 13

That LuaJIT process isn't the website build. It's a `git push` you started in
terminal 4 about 8 minutes ago, and it's been stuck for about 6 minutes on one
step. The push is waiting for it to finish.

**The chain:** the bash shell in terminal 4 ran `git push`. The repository has a
hook that runs before every push, and it rebuilds the conversation-transcript
web pages for every project in `ai-stuff`. That hook started the page builder,
and the page builder is the LuaJIT process (process number 30496).

**What it did, by its own records:**
- In its first few seconds (around 19:30) it wrote 544 pages, ending with the
  pages for commits made without a conversation.
- Since then it has written nothing and read nothing. Its read and write
  counters didn't change between two checks, while it kept one processor at
  about 96%.
- The next thing it would write is the repository-wide contents page. That page
  is still the copy from 12:37 today, 2.5 MB, which an earlier run wrote.

So it's working, without any file activity, on the step that sorts all 2,118
commits into groups and draws the contents page. I couldn't confirm whether that
step is just slow or stuck in a loop. This machine doesn't allow attaching a
debugger to another process ("Operation not permitted"), so I can't see which
line it's on. One clue: an earlier run today produced that page, and I have no
record of how long it took.

**Your options:**
1. **Let it run** if pushes from the repository root normally take this long.
2. **Press Ctrl-C in terminal 4.** That stops the page builder and cancels the
   push. Nothing is half-sent, because the hook runs before anything goes to
   GitHub.
3. **Push without the hook:** `git push --no-verify` skips the page rebuild. The
   transcript pages then stay out of date until the next push that runs it.

It's also using a processor your neocities build would want, so it's worth
deciding before you restart that build.

I haven't touched the process. If it's still running after you choose, I can
time the page builder on a copy in RAM to find out whether that step ever
finishes. Do you remember how long a push from the repository root took before
today?

--------------------------------------------------------------------------------

### User Request 14

ah got it. Don't worry about it then, I want it to keep running. How about the
neocities errors?

--------------------------------------------------------------------------------

### Assistant Response 14

> Fixing the fingerprint bug now so your build can go again.

> Writing a test that catches the lost fingerprints first, then the fix.

> The new test fails on the current code, the same way your build did. Now the
> fix:

> All 18 pass. Checking against your real pictures too:

> Updating the function's notes file to match:

The fingerprint bug is fixed, so you can restart the build.

**The fix:** before, all the fingerprint programs running at once wrote into one
shared pipe, where their answers could cut into each other. Now each group of 64
pictures writes its answers to its own small file in the RAM scratch folder. The
program reads those files once every group has finished. All processors still
work at once.

**Errors are clearer.** If pictures can't be fingerprinted, the error now says
how many failed and names the first one. If a fingerprint program fails even
though every picture got an answer, the stage stops and says so; before, that
failure went unnoticed.

**Checks:**
- **New test:** it fingerprints 600 files five times and requires every answer
  back every time. It failed on the old code with the same error your build hit,
  and it passes now. All 18 picture-step tests pass.
- **Your real pictures:** I fingerprinted all 701 input pictures five times, and
  all 701 came back each time. Your build counts 1,200 pictures because it also
  includes pictures from outside the input images folder. I didn't run that full
  set, but the fix doesn't depend on the number.
- **Notes file:** the picture step's notes file now describes the new way.

Nothing is committed yet. The changes are the fix, the new test, and the
notes-file update. Do you want me to commit them? The transcripts and word-cloud
records would go in with the commit.

**Still open from before:** the run script accepts several bare words (words
without leading dashes) and quietly keeps only the last as the project folder.
That's why your missing dashes caused a confusing "library not found" error.
Should a second bare word stop the run with an error that names it?

--------------------------------------------------------------------------------

### User Request 15

<pasted_content id="e071">
> Still open from before: the run script accepts several bare words (words
> without leading dashes) and quietly keeps only the last as the
> project folder. That's why your missing dashes caused a confusing "library not
> found" error. Should a second bare word stop the run with an
>   error that names it?
</pasted_content id="e071">


but don't we have a cli flag for the project directory setting? If so, then we
shouldn't accept any bare words.

--------------------------------------------------------------------------------

### Assistant Response 15

No, there's no flag for the project folder. A bare word is currently the only
way to set it.

- **`--dir PATH` doesn't do it.** It sets the assets folder (default: the
  project's `assets/`), not the project folder. The name is misleading, because
  the project folder's variable in the script is also called `DIR`.
- **The usage line shows the project folder as a bare word:** `./run.sh [FLAGS]
  [PROJECT_DIR]`. That bare word is your global rule that a script must accept
  its project folder as an argument.
- **Nothing passes a bare word today.** I checked the project's scripts and Lua
  files, and none of them call the run script with a folder that way. Refusing
  bare words wouldn't break anything inside the project.

So your idea needs one new flag first. My recommendation:
1. **Add `--project PATH`** to set the project folder, and treat every bare word
   as an error that names it. Your command with the missing dashes would then
   stop with "unexpected word: wordcloud-poems".
2. **Optionally, rename `--dir` to `--assets`** so the two folders can't be
   confused. This one touches more: the help text, the notes at the top of the
   script, and any docs that mention `--dir`.

Do you want 1 only, or 1 and 2? There's also no issue file for this yet. It's a
design change rather than a bug fix, so I'd look for an existing issue about the
run script's command-line values to reopen, and write a new one only if there
isn't one.

--------------------------------------------------------------------------------

### User Request 16

> - The usage line shows the project folder as a bare word: ./run.sh [FLAGS]
> [PROJECT_DIR]. That bare word is your global rule that a script
>     must accept its project folder as an argument.

this requirement can be gated behind a cli flag.

> - --dir PATH doesn't do it. It sets the assets folder (default: the project's
> assets/), not the project folder. The name is misleading,
>     because the project folder's variable in the script is also called DIR.

can we rename this then? maybe assets?

then let's do --dir as the project directory.

--------------------------------------------------------------------------------

### User Request 17

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

### Assistant Response 17

> Mapping how far `--dir` reaches before I write the issue. It's bigger than the
> run script alone.

> Issue written. Before editing the run script, checking whether your build is
> running: bash reads a script as it goes, so editing `run.sh` mid-build can
> break the running build.

I've stopped before changing any code, because your build is running right now
(`./run.sh --stage 6 ... --stage 10`, started about 3 minutes ago, and the
embedding step is working).

**Why I'm waiting:** each stage loads the shared Lua helpers fresh when it
starts. If I changed them now, the run script that's already running would keep
handing later stages `--dir`. The updated helpers would treat that as the error
I'm adding, and your build would stop at stage 7 or 8. Editing `run.sh` itself
mid-run is also unsafe, because bash reads the script as it goes.

**Picture fix:** the fingerprint fix is already in place, so this run's picture
step will use it.

**The plan, in `issues/10-076-folders-are-named-by-flags.md`:**
- `run.sh --dir PATH` sets the project folder, and `--assets PATH` sets the
  assets folder.
- Any bare word stops the run before any work, and the error names the word.
- Every child program takes `--assets` too, and a `--dir` given to a child
  program is an error. Without that, a leftover `--dir PATH` would quietly
  become a child's project folder. That's the same failure an earlier fix in the
  project had to undo once.
- Tests for both the run script and the child programs, then a dry run of the
  full build.

**Two open questions in the issue:**
1. Should every child program also take its project folder as `--dir` and refuse
   bare words, like `run.sh`? That touches every program, so it would be a
   bigger change. Until you decide, they keep the bare word.
2. The assets lookup quietly falls back to `<project>/assets` when nothing names
   the folder. A build never reaches it, because `run.sh` always passes the
   folder, but a child program run by hand can. Keep that fallback, or make it
   an error?

Should I start the changes once this build finishes? I can watch for it to end
and begin then, or you can tell me when it's done.

--------------------------------------------------------------------------------

### User Request 18

alright you can continue

--------------------------------------------------------------------------------

### Assistant Response 18

> Build finished; a deploy is running now. Checking whether it reads any of the
> files I'm about to change.

> The deploy doesn't load any of them, so it's safe to go ahead.

> Now the run script edits.

> Now the help text, usage lines and header notes.

> Pausing the rename to answer your question.

> Now the shared Lua helpers.

> Now `main.lua` and the three page generators.

> Checking every child program the run script hands the assets folder to.

> All four are covered. Now the embedding script and the seed test.

> Phase-16's `--dir` belongs to a separate phone server, so it stays. No docs
> mention the old flag. Now the tests: checking how the project's test runner
> finds them.

> The flag reaches the child programs. Writing the test file now.

> 18 of 18 pass. Now the whole test suite, and a dry run of your full build
> command:

> Your full build command plans cleanly: all 8 child-program calls get
> `--assets`, and none get `--dir`. Updating the notes files and the issues.

> The changed files have no notes files. That gap was there before this change,
> so I'll report it rather than fill it now. Updating the issue to describe
> what's built:

> Adding one pointer line to each of the two older issues:

The folder flags are built, and every test passes except two that need the
inference server, which isn't running. The issue stays open until you answer the
two questions at the end.

**What changed:**
- **Flags:** `./run.sh --dir PATH` sets the project folder, and `--assets PATH`
  sets the assets folder. The old usage line `[PROJECT_DIR]` is gone from the
  help text.
- **Stray words:** a word without a flag in front of it stops the run before
  anything is planned. With your earlier typo you'd now get:
  `Error: unexpected word on the command line: wordcloud-poems`
- **Child programs:** the four programs the run script starts (the main program,
  gallery, word cloud, word pages) and the embedding script all take `--assets`
  now. If one is handed the old `--dir`, it stops and names `--assets`. That way
  an old call can't quietly turn the assets path into the project folder.

**Checks:**
- A new test file, `scripts/folder-flags.test.sh`, passes all 18 of its checks.
  The project's test runner picks it up automatically, so it runs before every
  build.
- The whole suite: 55 passed, 0 failed. 2 couldn't run because the inference
  server is off: the fuzzy-computing batch test and the picture-sight test.
- A dry run of your full build command (`--dry-run`, which plans every stage
  without running them) hands `--assets` to all 8 child-program calls and the
  old `--dir` to none.

**Not changed:**
- The embedding script builds an assets argument that nothing reads. I renamed
  it and left it in place.
- None of the changed programs has the `.info.md` notes file your rules ask for.
  That was true before this change, so I didn't create them as part of it.
- Nothing is committed. Two pieces of work are waiting: the picture-fingerprint
  fix, and this flag change. Should I commit the fingerprint fix on its own now?
  This change would follow once the questions below are settled.

**Two open questions:**
1. The run script now takes its project folder only through `--dir`. The
   programs it starts still take theirs as the first plain word. Should those
   programs also switch to `--dir` and reject plain words? That would touch
   every program in the project.
2. When a child program is run by hand with no assets folder named, it quietly
   uses `<project>/assets`. A normal build never reaches this, because the run
   script always passes the folder. Should that silent default become an error?

--------------------------------------------------------------------------------

### User Request 19

> 1. The run script now takes its project folder only through --dir. The
> programs it starts still take theirs as the first plain word. Should
>      those programs also switch to --dir and reject plain words? That would touch every program in the project.

sure

> 2. When a child program is run by hand with no assets folder named, it quietly
> uses <project>/assets. A normal build never reaches this,
>      because the run script always passes the folder. Should that silent default become an error?

should remove fallback defaults

> - The embedding script builds an assets argument that nothing reads. I renamed
> it and left it in place.

let

--------------------------------------------------------------------------------

### User Request 20

[Request interrupted by user]

--------------------------------------------------------------------------------

### User Request 21

> 1. The run script now takes its project folder only through --dir. The
> programs it starts still take theirs as the first plain word. Should
>      those programs also switch to --dir and reject plain words? That would touch every program in the project.

sure

> 2. When a child program is run by hand with no assets folder named, it quietly
> uses <project>/assets. A normal build never reaches this,
>      because the run script always passes the folder. Should that silent default become an error?

should remove fallback defaults

> - The embedding script builds an assets argument that nothing reads. I renamed
> it and left it in place.

let's fix it

> - None of the changed programs has the .info.md notes file your rules ask for.
> That was true before this change, so I didn't create them as
    part of it.

let's make them

> - Nothing is committed. Two pieces of work are waiting: the
> picture-fingerprint fix, and this flag change. Should I commit the fingerprint
>     fix on its own now? This change would follow once the questions below are settled.

let's  commit things when they're finished.

question. Why the extra poems?



<pasted_content id="e071">
============================================================
Validation Summary
============================================================

Poem corpus:        8674 poems
Similar pages:      8674 / 8674
Different pages:    8674 / 8674
Chronological:      136 pages

✓ PASS: All poems are represented in generated output

✅ Pipeline completed successfully
Shutting down inference server (PID 9067) that this run started...
[ritz@kuvalu neocities-modernization]$ ./scripts/
audit-config-fallbacks file-screenshot render-image-post-comparison
audit-config-fallbacks.test.sh file-screenshot.test.sh render-page-sample
audit-config-keys find-in-transcripts run-notes
audit-config-keys.test.sh fsync-logger run-tests
audit-orphan-files generate-config-reference scrape-boost-content.lua
audit-orphan-files.test.sh generate-config-reference.test.sh
seed-reproducibility.test.sh
build-deps.sh generate-corner-box-demo stage-timing.test.sh
build-download-zip generate-hope-card-pdf start-llamacpp-server.sh
cache-dir install-deps.sh strip-excluded
check-inline-lua-quotes install-fonts sync-external-files
check-poem-dates list-inference-choices sync-page-templates
check-rankings-match-poems list-near-empty-poems test-effil-simple
check-table-of-contents measure-centering-effect update
check-table-of-contents.test.sh measure-embedding-spread update-words
compare-picture-embeddings measure-page-bytes validate-output
deploy-to-neocities model-propagation.test.sh validate-output.test.sh
ensure-site-in-ram notes-tooling-exclusion.test.sh validate-pipeline-data
ensure-tmp-symlink precompute-diversity-sequences-gpu
validate-poem-representation
exit-status.test.sh preflight-gate validate-poem-representation.test.sh
export-hope-cards preflight-gate.test.sh write-run-overrides
extract-bluesky-data                  quarantine-stale-output
[ritz@kuvalu neocities-modernization]$ ./scripts/deploy-to-neocities --prune
Hashing the local build and listing the live site ...
Local files: 44084 On site now: 35866 Upload (new/changed): 42850 (8.1 GB) Prune
(stale on remote): 21173
Upload 42850 files to the LIVE similar-different/ now? [y/N] y
Uploading to similar-different/ 30065/42850 steady; raising budget -> 67108864
  chronological
  ██████████████████░░░░░░░░░░
  88/137 64%
  different
  ████████████████████░░░░░░░░
  12256/17348 71%
  gallery
  ████████████████████░░░░░░░░
  5/7 71%
  media
  █████████████████████░░░░░░░
  13/17 76%
  other
  ███████████████████░░░░░░░░░
  4/6 67%
  similar
  ████████████████████░░░░░░░░
  12156/17348 70%
  source
  ███████████████████░░░░░░░░░
  421/605 70%
  wordcloud
  ███████████████████░░░░░░░░░
  5122/7382 69%

DEPLOY STOPPED: request failed at minimum batch size (status 413) on
similar-different/similar-different.zip
Re-run to resume (uploaded files are skipped).
</pasted_content id="e071">


17348 vs 8674

--------------------------------------------------------------------------------

### Assistant Response 21

> Each poem has two files in each of those folders, so 17,348 is 8,674 × 2.
> Checking the deploy failure now, since it blocks the upload.

> Checking whether a zip this size has ever made it onto the live site.

**Why 17,348 when there are 8,674 poems:** each poem has two files in
`similar/`, and two in `different/`.
- `bluesky-1-01.html` is the page you see. There's one per poem, because the
  build ran with `--pages 1`.
- `bluesky-1.txt` holds the same 64 poems, in the same order, as plain text.

So 8,674 pages + 8,674 text files = 17,348 in each folder. No poem is
duplicated.

**Why the deploy stopped:** the download zip is a single 2.37 GB file, and
Neocities refused it ("413" means the upload was too large). It had already been
cut down to a batch of one file, so there was nothing smaller to try. I listed
the live site (read-only), and the largest file on it is 90 MB, exactly
94,371,840 bytes. Those are your older archives,
`conversation-starters/conversation-starts.z06` through `.z11` and
`music/platinlord.z02`, which were split into 90 MB pieces. So the download zip
has never been on the site. My guess is Neocities caps each file at around 100
MB, and that's why the old archives were split. I haven't confirmed the cap from
Neocities itself.

**Where the deploy is now:** about 30,000 of 42,850 files went up. The rest
haven't been uploaded, and the prune hasn't run. Re-running will resume, but it
will stop on the zip again until the zip changes.

**Options for the zip:**
1. **Split it into 90 MB pieces** the way your older archives are, using zip's
   own split option (`zip -s 90m`). That gives about 27 pieces (`.z01`, `.z02`,
   …, `.zip`). The source browser's download link would point to a list of the
   pieces. A reader downloads them all and opens the `.zip`.
2. **Keep the zip off Neocities.** The deploy would skip it, and the download
   link would be removed or pointed elsewhere.
3. **Make the zip smaller.** For example, it could hold the source and one copy
   of each poem's text instead of the whole built site. That probably still
   won't fit in 100 MB without splitting.

Which do you want? The rest of the deploy waits on this choice.

**Your other answers:**
- Child programs take `--dir` and refuse plain words: yes.
- The silent assets default and the other fallback defaults: remove them.
- The embedding script's unused assets argument: fix it.
- Notes files for the changed programs: make them.
- Commits: each piece goes in when it's finished.

I'll start on those after you answer about the zip.

--------------------------------------------------------------------------------

### User Request 22

> Where the deploy is now: about 30,000 of 42,850 files went up. The rest
> haven't been uploaded, and the prune hasn't run. Re-running will
>   resume, but it will stop on the zip again until the zip changes.

so wait... should I run it with --prune now to continue, or not?

> 1. Split it into 90 MB pieces the way your older archives are, using zip's own
> split option (zip -s 90m). That gives about 27 pieces (.z01,
>      .z02, …, .zip). The source browser's download link would point to a list of the pieces. A reader downloads them all and opens the .zip.

oh, yes, we should do that. See this page for examples:

https://ritz-menardi.neocities.org/conversation-starters/conversation-starters

--------------------------------------------------------------------------------

### Assistant Response 22

> Your page confirms the cap. I'm designing the split now, starting with where
> the download is described in the issues.

> Free RAM covers the split step: the whole zip (2.4 GB) and its pieces (another
> 2.4 GB) fit in the 8 GB free. Writing the issue:

> Writing the issue file:

> Now the zip builder:

> Now the source-browser link and the run script's call:

> Now the test:

> The scratch project needs `tmp/` as a link, the same way real projects have
> it. Checking what the link helper accepts:

> A real problem: the pieces join, but the big file inside comes back corrupted.
> I'm narrowing down which step breaks it.

> Even a split made directly fails after joining, so the joining step is the
> suspect. Testing the pieces with 7-Zip, which is what most readers would use:

> The pieces themselves look fine to 7-Zip. The faulty part is zip's own joining
> command, `zip -s 0`, the very one I'd put on the page. Checking that 7-Zip
> extracts the file byte for byte:

> 16 of 16 pass. Making the test clean up after itself on every exit, including
> the early skip:

> Now applying it to your real built site: building the pieces, then redrawing
> the source-browser pages so their download link points at the new page.

> The pieces were built before the source pages were redrawn, so the copies
> inside the archive still have the old link. Rebuilding the pieces so they
> match:

> No broken links across 25,466 pages, so the new download page and all 26
> pieces resolve. Doing a dry run of the deploy (it lists and compares, and
> changes nothing):

> Updating the issue to describe what was built, then checking how the commit
> tool separates this piece from the unfinished flag work, since both touched
> the run script.

*[commit] a225037f0 in ai-stuff - neocities: picture fingerprints no longer get lost in a shared pipe*

> Committed. Updating the download issue's current behavior:

Yes, run `./scripts/deploy-to-neocities --prune` now. The download is ready as
90 MB pieces, so nothing larger than 90 MB is left to stop the upload. A dry run
plans 13,219 uploads (4.1 GB) and then the prune of 21,173 old files.

**What changed:**
- **The pieces:** the download is now 26 pieces in `output/download/`:
  `similar-different.z01` through `.z25`, plus `similar-different.zip`, 2,257 MB
  together.
- **The page:** `output/download/index.html` lists every piece as a numbered
  link, in the site's colours, worded like your conversation-starters page. It
  says how many pieces there are and to put them all in one folder.
- **Source-browser link:** the "download everything" link on every
  source-browser page now goes to that page. I redrew those pages and then
  rebuilt the pieces, so the archive holds the new links too.
- **Link check:** I ran the page check (`validate-output`) over all 25,466
  pages: no broken links.

**Readers need 7-Zip for this download:**
- **What broke:** zip's own joining command (`zip -s 0`, Info-ZIP zip 3.0)
  produced an archive whose big file came back corrupted.
- **What works:** 7-Zip opened the same pieces and the file came out byte for
  byte.
- **The page:** it tells readers to open the `.zip` piece with 7-Zip, which
  finds the rest itself. It doesn't say "extract like normal", because plain
  `unzip` can't read split archives at all.

**One thing I couldn't confirm:** each piece goes up as a single 90 MB upload.
Your older 90 MB archives are on the site, but I don't know how they were
uploaded, so I can't promise the upload API accepts a request that size. If the
deploy stops on a piece, tell me and I'll make the pieces smaller.

**Committed:** the picture-fingerprint fix, with the transcript and the
2026-11-02 word-cloud record (`a225037f0`).

**Not yet committed:**
- The download pieces will be committed once this deploy gets them onto the
  site.
- The folder flags (`--dir` and `--assets`) are still in progress. Both changes
  edited the run script, and the commit tool can only separate whole files, not
  lines.

**Next, after your deploy:** child programs take `--dir` and refuse plain words;
the fallback defaults are removed; the embedding script's unused assets argument
is fixed; and the missing notes files are written. I wrote one notes file for
the download builder as part of this change.

--------------------------------------------------------------------------------

### User Request 23

> - What broke: zip's own joining command (zip -s 0, Info-ZIP zip 3.0) produced
> an archive whose big file came back corrupted.

whoa hold up, that sounds like a bug. Investigate?



<pasted_content id="e071">
> One thing I couldn't confirm: each piece goes up as a single 90 MB upload.
> Your older 90 MB archives are on the site, but I don't know how
> they were uploaded, so I can't promise the upload API accepts a request that
> size. If the deploy stops on a piece, tell me and I'll make
>   the pieces smaller.
</pasted_content id="e071">


um, it should be our system. What changed?

> Next, after your deploy: child programs take --dir and refuse plain words; the
> fallback defaults are removed; the embedding script's unused
> assets argument is fixed; and the missing notes files are written. I wrote one
> notes file for the download builder as part of this change.

let's do this now.

--------------------------------------------------------------------------------

### Assistant Response 23

> Three things: the zip bug, what changed about uploads, and the remaining work.
> Starting with the zip bug, by finding the smallest case that breaks.

> No known bug report turned up in a quick search. One more check: whether
> there's a way to join without 7-Zip.

> The config-setting audit finds 0 fallback values (11 are marked optional on
> purpose), so what's left are folder fallbacks like the assets one. Finding
> those:

> Now the issue that lists the behavior fallbacks. Reading each one so it's
> described correctly:

> Writing the two shared readers, Lua first:

> Tests for both readers:

> The shell cases failed because the test's own quoting went through `sh`, not
> because of the reader. Switching to a small driver file run by bash:

> 18 of 18 pass, Lua and shell giving the same answers. Next, the checker, which
> first needs a firm definition of which files count as programs:

> The work list is 133 programs. Sorting them by how each reads its folder now,
> so a tool can handle the common shapes:

> Now every caller of those ten, starting with `ensure-tmp-symlink`:

> Nothing sources it; only its header mentions that it could be sourced.
> Rewriting its callers to pass `--dir`, all four spellings of the call:

> The safety gate needs every written path spelled out, so I'm making the call
> rewrites with a small Lua tool that takes literal replacements and reports
> each change:

> All 25 files that call it are rewritten. A quick check that the helper and
> three of its callers still work:

> The helper works, and a plain word now stops it by name. Next is the test
> runner, which hands the folder to every test:

> About 40 calls in the run script alone. The plan: convert every child program
> first, then one pass of rewrites over all the callers. Now the Lua tests, to
> see their exact spellings:

> All 20 converted. Now the Lua programs that read no folder from their command
> line. If they work out their folder some other way, `--dir` has to feed into
> that, not just be accepted:

> Adding the same "only when run" form to the folder reader:

> Now the dual-use modules, one at a time, starting with the colour calculator:

> Now the same change in the other dual-use modules:

> Still working through the 133 programs. Four audit scripts share one loop
> shape, where "a bare word is the project directory", so a small converter
> handles all four:

> The test itself was wrong: `luajit -e … some-word` treats `some-word` as a
> script file to run. Switching to a driver file:

> Now the callers inside the four audit tests:

> Expected: those tests still read their own folder from the first word, which
> is now `--dir`. This is the "other uses of `$1`" group of 20 shell scripts.
> Reading how each one takes its folder:

> Eight tests share one shape (`DIR="…"`, then "if there's a first word, use
> it"), so the shell converter gets a second pattern:

> All four pass. Next, the scripts whose own option loop ends with "any other
> word is the folder", starting with the page checker:

> The callers come in one pass at the end, once every program is converted.
> Next, the remaining shell scripts with their own loops:

> Nothing calls these four with arguments, so changing how they read their
> command line breaks no caller. `build-deps.sh` first:

> Bash 5.3 handles an empty list under `set -u`, so these are safe. Now
> `check-inline-lua-quotes`, which takes file names as plain words. I'm turning
> those into a repeatable `--file PATH`:

> Converting the last two tests in the sourced-library group:

> 62 programs done, 2 marked exempt, 71 to go. The rest of the list:

> Next batch: the remaining Lua tests. First, a check that three of them use
> their second or later words for something real, rather than tripping my search
> on a function's own `...` parameters:

> Only the first word in all three; the `...` matches were false alarms.
> Converting them along with the Lua tests that read no folder:

> Seven of the "0 uses" files work out a project folder some other way. Where
> that folder is the project's, `--dir` now feeds it:

> The replacement also hit `src/diversity-chaining.lua`, a library that hasn't
> been converted, so the name it now uses doesn't exist there. Putting that line
> back:

> Restored, with no difference left. One more test feeds in `--dir`:

> Removing the last use of the old guard, then making the same change in the
> four programs that carried their own copy:

> These five programs still carry their own copy of the guard. Rewriting each so
> the shared reader handles `--dir` and stray words. The gallery generator:

> That leaves the gallery's old parser unused, so removing it:

> The help lines that still show a bare `[DIR]` get one pass at the end, across
> every program. Next, the word-pages generator:

> Now the main program's early folder read:

> The main program is done. About 45 programs are left. Next batch, eight
> scripts:

> Now the three scripts that share the `provided_dir, … = parse_args(arg)`
> shape:

> Next, `strip-excluded`, `update`, `update-words` and `ensure-site-in-ram`:

> Still converting, about 40 programs left. `find-in-transcripts` takes the
> folder and then the search text as plain words, so the text becomes `--text`:

> Passes. Next, `file-screenshot`, which takes `[DIR] PICTURE NAME`:

> Passes. Next, the hope-card pair, `run-notes` and `test-effil-simple`:

> Four quick conversions: the PDF maker's input and output become `--input` and
> `--output`, and the other three read `--dir` through the shared reader.

> 99 converted, 34 to go. Next eight:

> The deploy isn't running right now, so editing it was safe. The usage lines
> get the final pass. Next, four scripts with positional files:

> The ambiguous "two or three plain words" pattern again. They become `--poems
> FILE` and `--cache-dir PATH`, and their one caller, the pre-build check,
> changes too:

> All 69 matches are real calls (one is a usage example in a header comment,
> which should change too). Applying:

> Down to 9 failures, and `folder-flags` is expected because it still checks the
> first part's rules. Reading the rest:

> A replacement that spans lines can't go in this one-pair-per-line file, so
> `model-propagation` gets a direct edit and the file keeps the one-line pairs:

> Passes. The word-pages test builds its own `arg` table to imitate a command
> line, but without `arg[0]`, so the generator now thinks it was loaded rather
> than run. It needs `arg[0]` and `--dir`:

> All four pass. Next, the pre-build check test and the RAM-site test:

> Two more programs called through variables (`"$GATE" "$DIR"`, and the deploy
> with `"$D"`). Searching for that whole shape across every file instead of
> fixing them one by one:

> Both pass. Next, the five pipeline stages left in `src/`:

> Each of these is also loaded by other programs, so each uses the "only when
> run" form. Checking which flags each takes:

> Converting all five:

> These take a second plain word too: a source to extract from, a temporary
> folder, or a file. Each operand becomes a flag. First, how `scripts/update`
> calls them:

> The Bluesky edit missed on whitespace. Reading the exact lines:

> Now `sync-external-files`: its optional source name becomes `--source NAME`,
> and the run script's call changes with it:

> 118 done, 15 to go. Reading the next five:

> Converting `measure-centering-effect`; after it, four programs are left:

> Editing the embedding script, one of the last four programs:

> Before applying: these strings could also appear in other files, where they
> mean something else. Checking:

> Next, the run script's calls to the three stages converted most recently:

> All correct except one: the zip builder's test passes a plain word on purpose,
> to check it's refused. Leaving that call alone and applying the other six:

> Four left: the run script, the zip builder, `phase-demo.sh` and
> `validate-poem-representation`, plus `libs/utils.lua`, which the checker
> counts because its first line is `#!`:

> `libs/utils.lua` is a library other programs load and is never run, so it gets
> the exempt marker. `validate-poem-representation` reads its options in two
> places, and both move to the leftover words:

> Now the zip builder, swapping the parser I wrote earlier today for the shared
> reader:

> A file that merely mentions the reader and happens to call `io.read` would
> still pass, since `io.read(` contains `.read(`. Tightening the test to "the
> reader loaded, then `.read` called on it":

> The tighter test caught the reader's own test, which loads the reader under a
> different name. Making its call match the standard form:

> Before removing it: where would a program then get its assets folder if
> `--assets` isn't passed? Checking `config.lua`, and which callers pass no
> `--assets`:

> The lookup's header already reads "CLI > config > error", so it now matches
> what the code does. Next, the two libraries that guess the project folder. The
> config loader:

> This found a real miss: the run script calls the pre-build check with a plain
> folder word, and my call rewrite didn't catch it. Finding it, and any others
> shaped like it:

> 23 of 23 pass. Argument lists built in arrays can hide more calls like that
> one, so here's a dry run of your full build command, watching for any refusal:

> The full plan-only run exits 0 with no refusals, and every planned call names
> its folder with a flag. Next, the help texts that still describe a plain-word
> folder:

> Only mentions and links there, no calls. Now the notes files. Counting how
> many of the programs changed in this work are missing one:

> That list only covers files my bulk tools changed. Recounting from git, so the
> files I edited one by one are included:

> `--missing` asks the checker for its list of programs, so the checker needs a
> `--list-programs` option:

> All 59 are new and untracked. Removing them, but only files whose third line
> is the tool's "made by" line, so nothing written by hand can be touched:

> Making `--missing` skip tests by default, so a rerun doesn't recreate them. A
> new `--include-tests` option takes them back in:

> Every non-test program now has notes: 59 written this time, 18 that already
> existed left alone. The tool's own notes were written before I added
> `--include-tests`, so refreshing that one:

> Next, the whole test suite and your full build command as a dry run, to check
> everything still works together:

> All five work on the real data. Updating the issue to describe what was built:

> Adding the server-manager finding to the behavior-fallbacks issue:

> All three issues validate. One thing is still open before committing: whether
> your deploy has run. A read-only check (it lists and compares, and uploads
> nothing):

Every program in the project now takes its folder as `--dir` and stops on a
stray word, and the folder fallbacks are gone. The whole test suite passes.
Nothing is committed yet, for the reasons under "Commits" below.

**The zip bug:** it's reproducible, and it's in zip's own joining command, not
in the pieces.
- **What breaks:** `zip -s 0` cuts short any file that spans more than two
  pieces. On a test archive with a 25 MB file in three 10 MB pieces, the joined
  archive was 20,971,613 bytes. It held the first two pieces and stopped; the
  third piece's 5 MB was missing. A file spanning two pieces came back fine
  every time, compressed or not.
- **Other ways to join:** concatenating the pieces and repairing them with `zip
  -FF` gives an empty archive, and `bsdtar` can't read split zips at all.
- **What works:** 7-Zip opens the same pieces and every file comes out byte for
  byte. That's why the download page points to 7-Zip.
- **Known bug?** A quick search found no report of it. My zip is version 3.0
  from 2008, the last release.

**Deploy:** nothing has gone up since the 413 stop: 13,219 files are still to
upload and 21,173 to prune. You run it the same way as before:
`./scripts/deploy-to-neocities --prune`.

**What changed for you at the command line:**
- `run.sh` is the same, except a stray word now stops it, and the project folder
  is `--dir PATH` if you ever need it.
- A few scripts that took files or text as plain words now take flags, for
  example `find-in-transcripts --phrase "…"` and `file-screenshot --picture
  FILE --name NAME`. The issue lists them all.

**What's built:**
- **All 130 programs** use one shared reader for Lua and one for shell.
  `check-folder-flags` checks that every program actually calls it, and it runs
  with the tests. The run script keeps its own parser, marked as such. Four
  files take no project folder at all, each marked with its reason:
  - `libs/utils.lua` is a library and is never run.
  - `exit-status.sh` and `stage-timing.sh` are sourced by other scripts.
  - `validate-output-worker.lua` is the page checker's internal worker, whose
    plain words are the page lists it's handed.
- **Folder fallbacks removed:**
  - The silent `<project>/assets` default is gone. The assets folder comes from
    `--assets` or from `config.lua`, otherwise it's an error naming both.
  - The config loader no longer tries two written-in folders, one of them where
    the project lived before it moved.
  - The inference-server settings no longer treat an unreadable `config.lua` as
    an empty one.
- **The embedding script** now requires `--assets` and uses it everywhere it
  used to write `$DIR/assets` itself. The unused argument is gone.
- **Notes files:** `scripts/write-info-notes` built 59 of them from each
  program's own comments. It never overwrites a notes file that already exists.

**Found along the way:** the embedding-server manager starts its own main
routine when the main program loads it. That was already true before this work.
I added it to the behavior-fallbacks issue (`10-078`) rather than change it
here.

**Commits:** nothing committed yet, for two reasons:
- The download pieces (`10-077`) aren't proven until a deploy gets them onto the
  site.
- The run script and the zip builder each hold lines from both changes, and the
  commit tool can only separate whole files, not lines.

My suggestion: after your deploy succeeds, I make one commit for both changes
and say so in the message. Is that alright?

**Two questions:**
1. Tests have never had notes files here; each test's header already describes
   it. Should they get notes too? `write-info-notes --missing --include-tests`
   would write 59 more.
2. The first of the behavior fallbacks in `10-078`: when the terminal's width
   can't be read, progress bars are drawn 80 columns wide. Should that stop with
   an error instead, or keep drawing at 80?

Sources (searched for a known report of the zip bug; none of the results
described it):
- [LuaDist/zip](https://github.com/LuaDist/zip)
- [zipsplit man page
  (Ubuntu)](https://manpages.ubuntu.com/manpages/noble/man1/zipsplit.1.html)
- [Zip 3.0
  README](https://grok.dragonflybsd.org/xref/dports/archivers/zip/zip30/README)

--------------------------------------------------------------------------------

### User Request 24

if you can't find a report on the bug, then it's a problem on our end. .zip is
too common of a format, and the zip utility is too ubiquitous for us to request
our users use a different type. Find out why it's a problem.

--------------------------------------------------------------------------------

### Assistant Response 24

> Investigating. First, exactly which zip build this machine has, and how it was
> compiled:

> Info-ZIP zip 3.0 from July 2008, Void Linux package `zip-3.0_6`. To find which
> step breaks, the next step is the source. Fetching zip 3.0's source and the
> patches Void applies:

> Void's four patches don't touch split archives, so this is stock zip 3.0. The
> copying of an entry happens in `bfcopy`:

> Adding a guard to the builder so a later change to the piece size can't bring
> the bug back:

> 19 of 19 pass, including the new zip-and-unzip path. Now rebuilding the real
> download at the new size, then checking that it joins and opens with plain zip
> and unzip:

> Rewriting the builder's notes file for the new size and the zip-first
> instructions:

It was our piece size. At exactly 90 MiB, zip's own way of joining split pieces
(`zip -s 0`) silently drops data. The pieces now come out at 92,159 KB, and
plain zip and unzip open the real download correctly.

**Why it broke:** zip 3.0 copies a file across split pieces in 16 KB chunks, and
it moves on to the next piece only after a read comes back short.
- **The first piece:** it starts with a few header bytes, so its last read comes
  back short and zip moves on correctly.
- **Every later piece:** it holds only file data. If the piece size divides
  evenly into 16 KB chunks, every read comes back full, the last one ends
  exactly at the piece's end, and the next read gets nothing.
- **The result:** zip treats that as the end of the file and stops, with no
  error. Everything after the second piece is lost. 90 MiB is exactly 5,760
  chunks.

That's why it only hit files spanning three or more pieces. The code is `bfcopy`
in zip's `fileio.c`.

**The test that confirmed it** (a 25 MB file in three pieces each time):

| Piece size | Divides into 16 KB chunks? | Result |
|---|---|---|
| 10,240 KB | yes | lost data |
| 10,000 KB | yes | lost data |
| 10,239 KB | no | joined whole |
| 10,241 KB | no | joined whole |

**The fix:**
- **Piece size:** 92,159 KB, which is 94,370,816 bytes, still under Neocities'
  100 MB cap. An odd number of kilobytes never divides evenly into any chunk
  size zip 3.0 can be built with, so it's safe everywhere, not just on this
  machine.
- **Guard:** the builder now refuses a piece size that would bring the bug back.
- **The real download:** 26 pieces. `zip -s 0` joins them into one archive of
  2,367,061,717 bytes and 44,772 files, and `unzip -t` reports no errors.
- **The download page:** it now gives zip and unzip first, with 7-Zip as the
  other way.
- **Test:** the zip builder's test checks the zip-and-unzip path byte for byte
  (19 of 19 pass). The page check finds no broken links.

**What it meant for the real site:** the largest file in the download is 81 MB,
smaller than one piece, so the old 90 MiB pieces would actually have joined
fine. The bug only showed in my test because I used a 200 MB file. The new size
keeps the download safe even if a bigger file is added later.

The deploy still hasn't run. `./scripts/deploy-to-neocities --prune` will upload
the new pieces.

**Still open:**
1. **Committing:** once the deploy has put the pieces on the site, can I make
   one commit holding both the flag change and the download pieces? Two files
   hold lines from both, and the commit tool can't split a file by lines.
2. **Notes files for tests:** tests have never had them, because each test's
   header already says what it checks. Should they get notes files anyway?

--------------------------------------------------------------------------------

### User Request 25

> 1. Committing: once the deploy has put the pieces on the site, can I make one
> commit holding both the flag change and the download pieces?
>      Two files hold lines from both, and the commit tool can't split a file by lines.

whoa whoa whoa whoa, the whole point of the commit tool was to split by lines.
Are you sure?

--------------------------------------------------------------------------------

### Assistant Response 25

> I'm not sure. I was going from one line of the commit tool's notes, and I may
> have read it wrong. Checking the tool itself:

You're right that it splits by lines; I described it wrong. Three facts from
looking:

1. **It does split by lines.** It works from its record of each block of lines
   this session changed, and keeps other sessions' lines out of the commit, even
   inside the same file.
2. **But you can't choose which of *my* blocks go in.** The only way to commit
   part of my work is by file (`-- path`). So within `run.sh`, all my blocks go
   together: the ~40 for the folder flags and the one block for the download
   pieces.
3. **Most of my `run.sh` lines show as "foreign" right now.** My bulk-edit
   scripts wrote them, and the record can't see that route. Before any commit I
   have to claim them as mine with `claim-own-change`. I've been keeping a list
   of every file those scripts touched.

**How tangled is it?** Less than I made it sound:
- **`run.sh`:** only one block belongs to the download pieces, the 4-line step
  that builds the zip (its comment and its call).
- **The zip builder, its test and its notes file:** all new, all download-pieces
  work. They call the new shared folder reader from the flag change, so the flag
  change has to be committed first.

**Ways to keep the two commits separate:**
1. **Flag change first, including that one `run.sh` block,** with a line in the
   message saying the zip step's `--dir` call and comment ride along. The
   download pieces get their own commit after the deploy. This is my
   recommendation: it's honest, simple, and nothing gets edited back and forth.
2. **Temporarily take the zip block's comment out of `run.sh`,** commit the flag
   change, then put it back for the second commit. That keeps a perfect split,
   but it means editing a file just to fool the record.
3. **Give the commit tool a way to choose blocks,** such as an option naming
   line ranges. That tool lives in the shared scripts folder, so it would need
   its own issue there.

Separately, the commit tool doesn't answer `--help`; it took the flag as a
folder name and failed. Your rules say every command-line tool must have it. It
belongs in that same shared-scripts issue.

Which way do you want? And for the flag change itself, the one open question is
still whether tests should get notes files too. Each test's header already
describes it, so I left them out.

--------------------------------------------------------------------------------

