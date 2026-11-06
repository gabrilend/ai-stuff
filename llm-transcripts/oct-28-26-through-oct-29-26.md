# Conversation Summary: 8683aad8-aaed-42c9-8ee1-ee34c5357d46

Generated on: 2026-11-03 11:52:25
Models: claude-opus-5-5

## Contents

1. 2026-10-28 17:59, after Request 2 - I built the delta-version project
   timeline (four PNGs plus an interactive HTML page), and all its tests pass.
   Next, please decide whether a project's birthday can come from the
   repository's first commit so I can close the issue and commit.

--------------------------------------------------------------------------------

### User Request 1

can we make in delta-version a system that determines when the project was first
created and then creates a timeline of when they were worked on? How it'd work
is the X axis is time when each of them started, and the Y axis is a bar chart
with mostly dark areas but some highlighted segments above that correspond to
time when they were being worked on - both axes use time, but they use it
differently. I want .png as output, with .HTML for creating custom
visualizations like it.

--------------------------------------------------------------------------------

### User Request 2

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

### Assistant Response 2

> Found an existing PNG writer in the shared scripts library; checking its
> interface and how the repo's history records each project before writing the
> issue.

> Writing the issue file now (next number is 067), then the gatherer, the PNG
> drawer, and the HTML page as three separate programs.

> Now updating the gatherer to keep sweep days as their own list.

> Gatherer works: 85 projects dated (earliest magic-rumble, 2025-09-10). Now
> writing the PNG drawer with its own small pixel font.

> The default picture renders correctly. Checking the other three axis
> combinations.

> All four axis combinations render. Now the HTML page; checking how other
> delta-version pages handle the feedback box first.

> No feedback-inbox convention exists in delta-version yet, so I'll leave that
> out and list it as an open question. Writing the page template.

> Now the builder that splices the data into that page, plus the runner script.

> Pipeline runs end to end. Checking that the page actually draws in a headless
> browser.

> Using my scratchpad instead for the check screenshot.

> The page draws correctly. Now the tests; checking how a sibling test builds
> its fixture.

> `luajit -e` gets no argument list; switching the helper to read its script
> from standard input.

> Fixture mistake: the scaffolding files rode in alpha's first commit, making it
> a two-project sweep. Committing the scaffolding on its own first.

> All 21 checks pass. Writing the companion `.info.md` files and the note beside
> the generated outputs.

> Now updating the issue's Current Behavior to match what was built and
> recording the open questions (it stays in progress until those are answered).

I built the timeline system in delta-version, and it works end to end. One
command, `delta-version/scripts/project-timeline.sh`, reads the repository's
history and writes everything into `delta-version/assets/project-timeline/`.
That's four PNG pictures, the data file they're drawn from, and an interactive
HTML page. The new test script passes all 21 of its checks, and I loaded the
page in headless Firefox to confirm it draws.

**How the chart works**
- **X axis:** one column per project, left to right in the order the projects
  were born.
- **Y axis:** each column is a dark bar that rises from the project's first day
  to today.
- **Lit bands:** a day the project was worked on is lit across the bar:
  - amber for a commit,
  - blue for a saved conversation (dated by its transcript's filename),
  - cream when both happened on the same day.

Both axes had a second reasonable reading, so I built both of each and made a
PNG for every combination:
- **X:** columns evenly spaced in birth order (the default), or each column
  placed at its birth date on a calendar scale.
- **Y:** every bar rising from a shared baseline so its height is its age (the
  default), or the Y axis being the calendar itself so the bars climb like
  stairs.

**The three programs, kept separate**
1. A gatherer reads the history and writes the data file. It draws nothing.
2. A PNG drawer reads that data and paints the picture. It uses the shared PNG
   writer that already existed, plus a small pixel font I wrote for the labels.
3. A page builder pastes the data into the HTML page. The page opens straight
   from disk and has:
   - switches for both axis modes and for each kind of footprint
   - a colour picker for each colour
   - a name filter, a minimum number of lit days, and sort orders
   - scale sliders
   - hover readouts that show the date under the pointer
   - a "save as PNG" button
   - a way to load any other data file in the same format

**Something I hit while building it.** The repository's first commit
(2025-12-15) changed every project at once, and for about thirty projects it's
their only commit. I first treated commits that touch more than 8 projects as
housekeeping rather than work ("sweeps"). That left those thirty projects with
no birthday at all. Now sweeps are a third, grey kind of footprint: they can set
a birthday, but they don't count as work. Sixteen projects still have no date
because they were never committed and never talked about. They're listed, not
drawn.

Nothing is committed yet. Your rule is to commit only after an issue is
finished, and the issue file for this (filed in delta-version's issues as
"project lifetime timeline") still has open questions. Two I'd like to start
with:

1. **Should a sweep be allowed to set a birthday?** Right now it does, so those
   thirty projects all appear to be born on the day the repository began, even
   though some are older. Each project folder probably holds evidence of when it
   really began, such as its oldest file or its vision note. What would you
   trust as a project's real birthday?
2. **Did work really stop between March and July 2026?** In the calendar
   picture, almost nothing is lit from 2026-03 to 2026-07, and no project was
   born in that stretch. Did you step away, or did the work happen somewhere the
   history doesn't show? If it's the second, something is hiding it, maybe the
   way imported histories were given estimated dates. What do you think it is?

The issue file also asks whether this page should get a feedback box
(delta-version has no feedback inbox yet) and whether days should glow brighter
when there were more commits.

Files are in `delta-version/assets/project-timeline/`:
- timeline-order-age.png
- timeline-order-calendar.png
- timeline-time-age.png
- timeline-time-calendar.png
- project-timeline.html

--------------------------------------------------------------------------------

