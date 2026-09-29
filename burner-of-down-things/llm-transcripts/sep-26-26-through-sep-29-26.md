# Conversation Summary: e8e4c82c-c417-4a78-b8c0-ac2908436973

Generated on: 2026-09-29 00:24:07
Models: claude-opus-5-5

## Contents

1. 2026-09-27 12:03, after Request 11 - I built the machine that turns someone's
   software into a blueprint and rebuilds it, and all seven phases pass their
   checks. Next, I need your yes or no on running one real Claude Code turn,
   which spends a little of your subscription.
2. 2026-09-27 12:15, after Request 12 - The machine that turns software into
   blueprints and back is built, and one real Claude Code turn passed. Next, you
   decide whether to restructure it around your
   other-people's-software-as-a-rubric strategem, and how a describe turn should
   tell rules from choices.
3. 2026-09-27 12:31, after Request 13 - The goal is a machine that rebuilds any
   software from its name, with your tweaks; the prototype is built and its live
   Claude Code turn passed. Next: tell me what should prove a rebuilt program
   really behaves like the original.
4. 2026-09-27 12:57, after Request 14 - We're building a machine that turns
   software into blueprints and rebuilds customizable versions from them. The
   check that uses workflows the builder never sees is done and committed. Next,
   you choose how a failing workflow decides which issue to repair.
5. 2026-09-27 13:13, after Request 15 - We're building the machine that turns
   software into blueprints and back, and failing workflows are now traced to
   the faulty part by dynamic re-abstraction. Next: tell me whether a partial
   fix should get another narrow pass or widen right away.

--------------------------------------------------------------------------------

### User Request 1

hi hi u make 4 me yes yes I have ten twermillion rubies 4 u if possibeel

--------------------------------------------------------------------------------

### Assistant Response 1

Happy to make something! The rubies are appreciated, but I don't know what you
want me to make yet.

What should it be? A few questions to narrow it down:

- Is it for this project (`burner-of-down-things`), or something else?
- What kind of thing: a program, a document, a tool, a demo page?
- Is there a vision note or an issue file I should read first?

--------------------------------------------------------------------------------

### User Request 2

me me the vision from me, for thee oh computer friend to be.

--------------------------------------------------------------------------------

### Assistant Response 2

I read the vision. Here is how I understand it, and where I'm stuck.

**My reading of it, piece by piece:**

- **"harnesses artificial leverage"**: it uses a language model as a lever, so a
  small input produces a lot of output.
- **"facsimilic reprojections of concept software"**: you give it a
  *description* of a program (the concept), and it produces imitation versions
  of it (facsimiles). Maybe several different takes on the same idea.
- **"a dynamically recentering machine"**: the machine has a center of gravity,
  meaning the concepts it currently cares about most. That center moves as new
  inputs arrive.
- **"a personality that depends on its interactions… and guide its actions
  from that only"**: the machine keeps no fixed goals of its own. Its
  temperament is built up from the record of who talked to it and how. That
  record is what decides what it does next.
- **"the evil singularity is predictable in kind"**: this part is the reason for
  the whole thing. If behavior comes only from logged interactions, you can read
  the log and predict what it will do.

**Why I haven't started:** the vision is poetry. I could scaffold the project
right now (docs, roadmap, issues), but every document would rest on guesses.
These open questions change the design, so I'd like answers first:

1. **What does it take in, and what does it put out?** A text description in and
   runnable Lua programs out? Or sketches, docs, or diagrams?
2. **What is the "center"?** Is it a weighted list of topics? The most recent N
   interactions? Something that decays over time?
3. **Where does the personality live?** An append-only log that is replayed to
   rebuild its state (this fits your checksum-verified memory idea)? Or a small
   set of numbers, like moods, that get nudged by each interaction?
4. **Which model does it call?** Claude through the API, a local model, or none
   at all, meaning a rule-based machine with no AI inside?
5. **The name "burner-of-down-things":** does it burn things down? Does it throw
   away old reprojections as the center moves?

I'd suggest answering #3 first. The rest of the machine hangs off how memory
works.

--------------------------------------------------------------------------------

### User Request 3

"Hi, this is my version of Microsoft Basic" like that but for whichever target
the user specifies in plain language and using whatever technology marvels the
claude-code skill files tell it how to build. constrained in it's direction,
magnifying chosen perception, like a gyroscope that doesn't stand still.

--------------------------------------------------------------------------------

### Assistant Response 3

That clears it up. Here's the refined picture.

**What it is:** a machine that builds a small programming language for whatever
target you describe in plain English. It follows the same move as the Altair
BASIC story. Someone points at a machine (a Game Boy, a WoW server's Lua, a
browser tab, a microcontroller) and says "give it a language." The machine
writes the interpreter, the vocabulary, and a first program that runs on it.

**How it builds:** it doesn't invent its methods. It reads your skill files and
uses the techniques they describe:
- **canvas-and-paintbrush**: a small closed vocabulary that renders to files,
  with every output kept and rated.
- **polyglot-source**: the same interpreter written by hand in several languages
  side by side, with one of them live.
- **upstream-patch-system**: patching a target's own source code when the
  language has to live inside someone else's program.
- **project-init** and **issue-lifecycle**: the scaffolding it lays down for
  each language it creates.

**The gyroscope:** a gyroscope keeps its axis because it spins, and the axis
precesses (drifts slowly) when a force pushes on it. As I read it:
- The **axis** is the direction you chose: the target plus the purpose. This is
  the "constrained in its direction" part.
- The **spin** is the machine generating, rating, and regenerating nonstop.
  Whatever rates highly gets magnified, which is the "magnifying chosen
  perception" part.
- The **drift** is the personality. Each interaction tips the axis slightly, so
  over time the language grows into the shape of the people who used it. Nobody
  sets it by hand.

**Open questions before I scaffold:**

1. **Who runs the machine?** Does it call Claude itself (Claude Code in headless
   mode, reading the skill files), or is it a set of prompts and tools that a
   Claude session follows by hand?
2. **What counts as "done" for one language?** An interpreter that runs a
   hello-world on the target? Or one that runs a demo program you rate highly?
3. **What pushes on the gyroscope?** Your ratings of outputs, the programs
   people write in the language, or both?
4. **May I store your words?** I'd add today's description next to the original
   vision (in `notes/vision`, per your layout) and keep the poetry exactly as
   written.

Once you've answered, say "init" and I'll run the project setup: skeleton, docs,
a phased roadmap, and issues.

--------------------------------------------------------------------------------

### User Request 4

see /home/ritz/programming/ai-playground/kiln for details

--------------------------------------------------------------------------------

### Assistant Response 4

I read kiln's vision, its overview document, its roadmap, the umbilical
document, and the plan for raising a device that can't think. Here is how
burner-of-down-things fits next to it, as far as I can tell.

**Kiln** is a mind that runs on bare metal with no operating system under it.
Its ninth phase, the umbilical, describes something close to what you want here.
A development machine is plugged into a small board by one cable. A
**surrogate**, meaning whatever model you have (Claude Code, an API, a local
model), sits on the development machine. It reads the board's replies from a
mailbox, writes requests back, and builds the board's software directly. That
phase settled three rules:
- The surrogate never builds a mind.
- What it builds is installed as if the device had built it itself.
- The device can be plugged back in any day to keep growing.

**burner-of-down-things**, as I now read it, is that surrogate pulled out into
its own tool, with a narrower job. The kiln surrogate builds drivers and
applications. This one builds a **language**, the device's own BASIC:

1. You describe a target in plain language: "a Game Boy", "an ESP32 with a
   screen", "the Lua inside a WoW server".
2. It works out what the target is, using the approach of kiln's probing and
   description work.
3. It writes a small interpreter for that target, a vocabulary that fits the
   hardware, and a first program that runs on it. How it builds each piece comes
   from your skill files, not from its own invention.
4. It "burns it down" onto the thing, the way people once burned ROMs. Kiln
   fires the pot; the burner writes the glaze onto whatever it's pointed at.

**The gyroscope:** the axis is the target plus your stated purpose, and the
machine can't leave it. The spin is generating, testing, and rating. Whatever
rates well gets magnified, so it keeps moving without falling over.

**Open questions (these change the design):**

1. **A separate project or part of kiln?** Should burner-of-down-things be its
   own repository that borrows kiln's cable, flashing, and mailbox pieces? Or is
   it kiln's surrogate grown up, which would mean changing kiln's phase 9
   instead?
2. **Hardware only, or any target?** Kiln's surrogate only touches physical
   boards. "The Lua inside a WoW server" or "a browser tab" have no cable and no
   flashing. Should those count as targets?
3. **Why BASIC specifically?** Is the point that the output is a *language*
   someone else programs the device in? Or is "my version of Microsoft BASIC" a
   metaphor for "the first software a new machine gets"?
4. **Does kiln's "never builds a mind" rule carry over?** I'd assume yes, but
   I'd rather ask.
5. **May I store your words** (the vision plus today's three messages) in
   `notes/vision`, keeping them exactly as written?

When these are settled, say "init" and I'll lay out the project.

--------------------------------------------------------------------------------

### User Request 5

"uh, you want a discord clone? Okay my example is in
/home/ritz/programs/rao-chat/, that's how I'd build one"

"oh neat you built an azerothcore server, mine's at
/home/ritz/games/azeroth-core/wow-chat-2026"

"huh so it's like dropbox, except it's shared between two or more people?"

"wow I didn't know people made every single program and posted it's source-code
online"

"gee wonder if there's a way to combine these into a meta platform. we could
just call it \"the software\" and \"make it as often as we need-able tools\"
which could be nifty"
\
][ might have a new name soon

--------------------------------------------------------------------------------

### Assistant Response 5

Both folders exist, and I think the idea finally clicked. Here's what those four
lines of dialogue describe.

**It's a library of your blueprints, rebuilt on request.** Your projects are
built so that anyone can recreate them from scratch by redoing the completed
issue files in order. So each project is really two things: the software, and
the **blueprint** for making the software. rao-chat is a blueprint for "a chat
program." wow-chat-2026 is a blueprint for "a patched game server." A meta
platform lines them up in one catalogue:

- **"You want a discord clone?"** The platform looks up its nearest blueprint
  (rao-chat) and says "here's how I'd build one."
- **"Like dropbox, but shared between people?"** Nothing in the catalogue
  matches exactly, so it finds the closest pieces and combines them.
- **"People posted every program's source online?"** Other people's open-source
  projects are catalogue entries too. They have code but no blueprint yet, so
  the platform writes blueprints from them. This is the same move as kiln's
  probing: read what exists and describe it before changing anything.
- **"Make it as often as needed":** a blueprint gets replayed onto a new target:
  new hardware, new language, a new person's taste. Each replay is a fresh
  build, not a copy.

That connects to your earlier words. "My version of Microsoft BASIC" is the
output: someone's own version of a known program. The skill files are how it
gets built. The gyroscope's axis is the blueprint it's replaying, and the spin
is rebuilding and rating each replay.

**Open questions:**

1. **What is a catalogue entry?** A pointer to a project folder that stays where
   it is? Or a copy of that project's issue files, pulled into this platform?
2. **What does "make it" produce?** A new project folder, laid out the house
   way, with the blueprint's issues re-numbered for the new target and waiting
   to be worked? Or finished, running software?
3. **Who does the replaying?** A Claude session working through the issues one
   by one, as they were built the first time? Or kiln's surrogate?
4. **The name:** "][" suggests the Apple ][. Should I hold off on creating
   anything until the new name lands, so the folder doesn't have to be moved
   later?
5. **May I save today's words** (the vision plus these messages) into
   `notes/vision`, exactly as written?

--------------------------------------------------------------------------------

### User Request 6

actually, not quite. The first part was right. Instead, it takes a piece of
software and describes it in issue files. Then it delivers a design that meets
those specifications to you. Feel free to request updates anytime, it can solve
them instantly.

--------------------------------------------------------------------------------

### Assistant Response 6

Got it, corrected. The pipeline is:

1. **In:** a piece of software, any piece, yours or someone else's.
2. **Describe:** it writes issue files that specify the software: what each part
   does, how the parts connect, and in what order they're built. This is the
   blueprint.
3. **Deliver:** it builds a new design that meets that blueprint and hands it to
   you. The design is written from the specification, not copied from the
   original. That is a clean-room rebuild, the same approach your "describe,
   build, check" loop in wow-chat-2026 already uses for models.
4. **Update:** you ask for a change. The change becomes an edit to the
   blueprint, and the design is rebuilt to match.

**One technical concern about "instantly":** a change that touches one issue
file can be rebuilt quickly, because only that part and whatever depends on it
changes. A change that touches the foundation, like "make it peer-to-peer
instead of client-server," ripples through everything built on top and takes as
long as those parts take to rebuild. I think the honest promise is that every
update is *mechanical*: edit the spec, then rebuild whatever depends on the
edit. That can't be instant for deep changes. Is that close enough to what you
mean, or is there a trick I'm missing?

**Other open questions:**

1. **What form does the incoming software arrive in?** Source code only, or also
   finished programs with no source, where it would have to describe the
   software from behavior alone?
2. **Is "a design" working code, or an architecture a person then builds?**
3. **Name:** should I wait for the new name before creating anything?
4. **May I save your words** into `notes/vision`, exactly as written, including
   this correction?

--------------------------------------------------------------------------------

### User Request 7

yes yes that describes it almost completely, we will offer update grades as we
go along

--------------------------------------------------------------------------------

### Assistant Response 7

Good. My reading of **update grades**: each change request is sorted by how deep
in the blueprint it reaches, and the grade tells you what the rebuild involves
before it starts.

- **Surface:** touches one issue file with nothing built on top of it. Rebuilt
  almost at once.
- **Middle:** touches a part that others depend on. Rebuilt along with
  everything that uses it.
- **Foundation:** changes an early, low-numbered issue. Most of the design is
  rebuilt.

The grades get defined as we go, from real updates, not guessed up front. Tell
me if that's not what you meant.

Still open before I build anything:

1. **What form does the incoming software arrive in?** Source code only, or also
   programs with no source?
2. **Is the delivered design working code,** or an architecture that a person
   then builds?
3. **The name:** should I wait for it, or start under `burner-of-down-things`?
4. **May I save your words** (the vision plus today's messages) into
   `notes/vision`, exactly as written?

Answer those and say "init", and I'll set up the project.

--------------------------------------------------------------------------------

### User Request 8

> 1. What form does the incoming software arrive in? Source code only, or also
> programs with no source?

source-code, the language of creation, is created by language creating
creations.

--------------------------------------------------------------------------------

### Assistant Response 8

I'll record that line as written; it goes in the vision.

My reading: source code is the input, because source is the language the
software was created in. The line also describes the platform itself as a loop:

- **language creating creations:** the issue files, written in English, create
  the new design's source.
- **source code, the language of creation:** the incoming software's source is
  where the English gets read from.

So the platform reads source to get language, then uses that language to write
new source. Language turns into source and back again, and each update goes
around the loop once more.

If so, a program with no source is out of scope. It has no language of creation
left to read. Correct?

Remaining questions:

2. **Is the delivered design working code,** or an architecture a person then
   builds?
3. **The name:** should I wait for it?
4. **May I save your words** into `notes/vision`?

--------------------------------------------------------------------------------

### User Request 9

> 2. Is the delivered design working code, or an architecture a person then
> builds?

the harness and etceteras

  3. The name: should I wait for it?

never name such a thing

>   4. May I save your words into notes/vision?

you can do so as you please

--------------------------------------------------------------------------------

### Assistant Response 9

I saved everything to `notes/vision`. The original five lines come first. Below
them are all of today's words in order, exactly as you wrote them, then a short
plain-English summary marked as only my reading.

Two notes:

- **The original `vision` file at the project root is untouched.** The project
  folder isn't in git yet, and your rule says never to move something unless
  both the old and new versions are tracked. So the file now exists in two
  places. Once the folder has its first commit, I can move the root copy into
  `notes/`.
- **"The harness and etceteras"** is recorded as the answer about what gets
  delivered. My reading: the output is working software, meaning the harness
  that runs it plus whatever it needs around it, not a plan for a person to
  carry out. Tell me if that's wrong.

No name, ever. I'll treat `burner-of-down-things` as the folder's location, not
as the thing's name.

Say "init" when you want the skeleton, docs, roadmap, and issues.

--------------------------------------------------------------------------------

### User Request 10

init

--------------------------------------------------------------------------------

### User Request 11

Base directory for this skill: /home/ritz/.claude/skills/project-init

# Project init

The owner's CLAUDE.md defines what a project is made of and how it is
initialised, and it is the authority throughout; where it and this skill ever
disagree, CLAUDE.md wins and this skill is the thing to fix. This skill adds
only what CLAUDE.md leaves open: which tool builds the skeleton, in what order
the loop runs, and when each step is finished.

## 1. Lay out the skeleton with the tool, not by hand

    /mnt/mtwo/programming/ai-stuff/scripts/init-project.sh --skeleton-only <project-path>

It works for any folder, inside the monorepo or not, existing or not, and adds
only what is missing: the standard folders and intent folders, `docs/HTML/`,
`issues/completed/demos/`, `llm-transcripts/`, `docs/table-of-contents.md`,
`.file-index-counter`, `issues/phase-1-progress.md`, the root `run-phase-demo`
picker, the RAM scratch tiers behind `tmp/`, `tmp` in `.gitignore`, and a
plain-text `README` in every folder it leaves empty, saying what the folder is
for (git keeps no empty folder, so without it the folder never reaches a
remote). Those notes are part of the first commit. It is safe to re-run; on a
project that already has everything it changes nothing.
Read its report: it names what it built.

A project the owner wants to run an agent inside with permission checks off
gets the full form instead (a bare project name, inside the monorepo), which
adds a RAM sandbox. That is the owner's call, never a default; ask.

Anything the skeleton does not cover and CLAUDE.md asks for is a gap in the
tool. Make it by hand only if the owner says to, and note it in
`scripts/issues/026-skeleton-without-a-monorepo.md` so the tool learns it.

The `tmp/` link opens onto RAM, which a reboot empties. Scripts written for the
project that write into `tmp/` start by sourcing
`/mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers` and calling
`ensure_ram_tiers "${DIR}"` (Lua programs: `libs/ensure-ram-tiers.lua`), so the
tiers are rebuilt before they are needed rather than failing after a restart.

## 2. The documentation loop

Start from `notes/vision` (or whatever the vision file is called in `notes/`).
If there is none, stop and ask for one: everything after this point is
derived from it, and inventing a vision would make the whole project a guess.

Then follow CLAUDE.md's initialisation loop. The parts that are easy to get
wrong:

- **Repeat until there is nothing reasonable left to write.** Each pass reads
  the vision and everything already in `docs/`, then writes what is missing
  or improves what is thin. A pass that finds nothing new to create re-reads
  and sharpens the existing documents instead; that is the stopping signal
  approaching, not a reason to stop immediately.
- **Every new document goes into `docs/table-of-contents.md`** in the same
  pass that creates it.
- **Phases are clusters of functionality, not calendar stages**, and they are
  named in the table of contents from the start. Foundational pieces get low
  phase numbers because others build on them, not because they come first in
  time.
- **One datapath document per major feature**, showing how data moves through
  it. These are the documents later issue work updates, so write them as the
  current design, not as a plan.
- **The roadmap is split into phases**, and each phase says what it ends with
  (its demo).

## 3. Roadmap into issues

Break the roadmap into issue files following the issue-lifecycle skill, which
owns naming, numbering, the required sections, sub-issues, and phase progress
files. Number by foundation, not by the order you think of them: the issue
others build on gets the lower number. Give each phase's
`issues/phase-N-progress.md` its goals from the roadmap as the phase is
written.

## 4. Finish

- Run `run-phase-demo` once: with no demos yet it should say so and exit
  cleanly, which proves the picker and the demos folder are wired.
- Commit following issue-lifecycle's commit rules, with the transcripts.
- Report what was created, what the tool did versus what was written, and
  every open question met along the way. CLAUDE.md treats a task holding an
  unanswered open question as unfinished, so say plainly which questions are
  still waiting.

--------------------------------------------------------------------------------

### Assistant Response 11

> Setting up the project now: the skeleton is laid, and I'm reading your house
> tools before writing the docs, roadmap, and issues. Then I'll build it phase
> by phase.

> Writing the design documents now: what it is, the core terms, one datapath per
> major part, then the roadmap.

> Docs are half written: what it is, the terms, and the case, survey, hands,
> blueprint, and design datapaths. The update, center, open questions, and
> roadmap are next.

> Docs are done; writing the issue files next, phase by phase.

> Adding `delivered` to the ledger kinds now rather than later, then phases
> 6–7.

> Docs, roadmap, and 39 issue files are written and they validate clean.
> Committing the initialization now.

*[commit] 0fdefd4d7 in ai-stuff - Lay out the machine that turns software into blueprints and back*

> Initialization is committed. Starting phase 1: the launcher, text tables,
> SHA-256, the ledger, the case folder, and the dispatcher.

> Phase 1 code is nearly done. I'm fixing the order of operations so nothing is
> written to the ledger before the lock is held and the ledger has been checked.

> Phase 1 checks mostly pass. Two small fixes: the RAM scratch space won't
> execute scripts directly, so the check runs the launcher through bash, and a
> harmless error line gets tidied.

> Phase 1 is built: 355 checks pass and the demo runs. Closing out its issues
> now.

> Moving the phase 1 issues to completed and updating the progress file.

*[commit] 0e6c7c17c in ai-stuff - Give the machine a memory it cannot quietly rewrite*

> The warnings come from my own `git mv` staging. Resetting those index entries
> to match the commit:

> Phase 1 is committed and the tree is clean. Starting phase 2, the survey:
> reading a source tree across all cores without a model.

> The count was my arithmetic, not the survey: there are 13 files. Correcting
> the check:

> Phase 2 checks pass (50 new). Building the phase 2 demo next: surveying your
> own projects side by side.

> The AzerothCore source (8,518 files) makes a good speed test, but it's C++,
> which the language table doesn't know yet. Adding C++ rows:

> Dealing files round-robin brought 12 threads down to about 3.3 seconds.
> Single-thread time is still high, so I'm checking where it goes.

> Line counting was nearly all of it: `gsub` copies each file while counting.
> Replacing it with a plain search loop:

> The survey went from 11.4 seconds to 1.7 on one thread and 0.63 on twelve.
> Fixing the demo's column padding to count characters instead of bytes:

> Writing the phase 2 info files and closing its issues.

> I'm writing a small tool to close issues, since each phase repeats the same
> steps: rewrite the current behavior as built, then move the file to completed.

*[commit] 38d84c6db in ai-stuff - Teach the machine to read a source tree without a model*

> Writing the turn kinds and their prompt templates, the instructions each turn
> gets, and the snapshot comparison.

> Links get special handling: a symbolic link's checksum should be where it
> points, not the bytes behind it, and the snapshot must never follow a link
> into the RAM scratch space.

> Next: the harness table (stand-in and Claude Code), the stand-in program
> itself, and the pool.

> Now the checks for phase 3, covering the clean-room rule, snapshots, the
> harness table, and the pool, including misbehaving turns.

> All 56 phase 3 checks pass on the first run. Writing the phase 3 demo, plus a
> live Claude Code check that stays unrun until you say so.

> Phase 3 checks: 60 pass. Re-running the demo to confirm the fixes:

> The first snapshot of the 1.9 GB tree takes 14 seconds. Checking whether one
> huge file dominates:

> First snapshot went from 14 seconds to 1.5. Adding a check for the size limit,
> then info files, doc updates, and closing phase 3.

> The check's files are exactly 2 bytes, so a limit of 2 doesn't exceed them.
> Setting the limit to 1:

> Reopening 305. Its live check hasn't run, and by your rule an issue with
> deferred work stays in progress.

*[commit] 8877b178c in ai-stuff - Give the machine hands that stay inside their folders*

> The house validator works on a blueprint folder and catches dangling blockers.
> Writing the phase 4 modules:

> The fixture program works. Now its hand-written blueprint: the outline and six
> issue files, the kind a good describe turn would produce.

> Now the fixture design: the code and tests a build turn would write from that
> blueprint alone.

> The fixture design passes all six of its own acceptance tests. Now the
> stand-in script that plays this blueprint and design back, with switches to
> make chosen turns fail first:

> Writing the phase 4 checks:

> Phase 4 checks: 39 pass. Writing the phase 4 demo: the fixture described with
> a bad first outline and a failing issue caught and retried, the graph drawn as
> columns, and the coverage map.

> The phase 4 demo works: the bad outline and the twice-failing issue are caught
> and retried, and the house validator passes the whole blueprint. Closing phase
> 4:

*[commit] d8cda538e in ai-stuff - Write software down as a blueprint the house validator accepts*

> Phase 4 is committed. Starting phase 5, the design. First checking how the
> house RAM-tier helper names the second tier behind an existing link, since
> every case's design folder is called `design`:

> All checks still pass. Now the build step: waves, repairs, holds, and
> delivery.

> My shell's `%q` doesn't make Lua quotes. The machine handled it properly:
> three failed outline turns, each with the stand-in's error. Rerunning with a
> correct script line:

> Adding the fixture-case helper to the check kit, then the phase 5 checks:

> Phase 5 checks: 39 pass. Checks also leave each case's design scratch space
> behind in RAM, so the kit will now remove those at the end:

> Clean. Now the phase 5 demo:

> The demo works end to end, and the delivered program runs. One small count is
> off: it included the skeleton's README files. Fixing that, then closing phase
> 5:

*[commit] fb66efd84 in ai-stuff - Build new software from a blueprint alone, and deliver it*

> Now the rebuilt code for each request, derived from the fixture design:

> Now the update modules: locating and grading, amending with a way back, and
> the update loop.

> Replacing the `goto` with a function per request (LuaJIT allows `goto`, but a
> function reads more plainly), and letting a breach stop the run rather than
> just failing one request:

> Now the command rows for `update` and `grade`:

> One check at the end always passed (`or true`). Making it real:

> Phase 6 checks: 34 pass. Writing the phase 6 demo:

> That "touches" line is tangled. Simplifying it before running:

> The phase 6 demo shows each grade's reach on the graph, the foundation request
> held until `--go`, and the program changing after each request. Closing phase
> 6:

*[commit] 744d890e8 in ai-stuff - Grade change requests by how deep they reach, and rebuild outward*

> Wiring the center into the describe, build, update, and grade commands:

> Now the `run` logic, which reads what a case is waiting for from its ledger
> alone:

> Two gaps in `run`'s bookkeeping: an unsurveyed case skipped waiting requests,
> and held requests would make every `run` look unfinished. Held requests wait
> for the person, not for `run`:

> Node is present, so the checks can run the page's script with a minimal
> stand-in document and confirm its own chain check agrees with the machine.
> Writing the phase 7 checks:

> The installed node is broken on this system: a library mismatch unrelated to
> this project, so node can't start at all. Looking for another JavaScript
> engine:

> gjs (GNOME's JavaScript engine) is installed. The page check will build one
> self-contained script and run it with whichever engine actually starts, saying
> which one it used:

> The ledger lines sit in the page as JSON, where tabs are written `\t`, so the
> raw line never matches. Tampering with line 2's text as it appears in the JSON
> instead:

> Closing phase 7: info files, docs, the balance record, the issues.

> Everything except issue 305 is closed. All 11 check files pass. Committing
> phase 7:

*[commit] 0fd9249b3 in ai-stuff - Give the machine a personality it can only earn from its record*

The machine is built: all seven phases, with every piece except one tested and
demonstrated.

**What it does now**

You hand it a folder of someone's source code and run one command. It:
1. Reads the code without a model: every file, its language, and which file
   includes which. This runs across all 12 cores and takes 0.6 seconds on the
   8,500-file AzerothCore tree.
2. Plans a blueprint as issue files, checks the plan itself, and writes every
   issue in parallel. Your own issue validator passes the result.
3. Builds new code from the blueprint alone. The build turns cannot see the
   original source. Each piece is checked by running its own tests, repaired up
   to twice, or held back along with everything built on it.
4. Takes change requests in plain words, grades each one (surface, middle, or
   foundation) by how much of the design it would rebuild, and holds foundation
   changes until you say go.

Every event goes into a chained, append-only record, so editing any past line is
caught at that exact line. The machine's personality is computed from that
record and nothing else; it decides what gets done first. Each case can also be
written as one HTML page that checks its own record.

**How to see it:** run `./run-phase-demo`, then pick 1–7. Phase 7 is the whole
machine at once, and it opens the case page in Firefox. `tests/run-tests` runs
all the checks, and all 11 check files pass.

**Things you should know**
- **Every demo used a free stand-in instead of a real model.** It plays back a
  hand-written blueprint and design of a small notes program. The Claude Code
  connection is built and its command line is checked, but it has never run for
  real, because that spends your subscription. Its issue stays open for that
  reason.
- **Node is broken on this system.** It fails to start with `undefined symbol:
  sqlite3session_attach`, a library mismatch unrelated to this project. The page
  check falls back to gjs, and the check output says so.
- **The original `vision` file at the project root is still untracked.** Your
  words are safely in `notes/vision`. I didn't move the root copy, because your
  rule says both versions must be in git first.
- **Real bugs the demos caught along the way:**
  - The C include scanner had been silently finding nothing.
  - A Claude Code turn could have read earlier turns' records, which can quote
    the source.
  - The shared command-runner misread exit codes.

  All are fixed, and checks now hold them.

**Eight open questions** are listed in `docs/010`, so by your rule the task
isn't finished. The first one, since it decides whether issue 305 can close:

May I run one real Claude Code turn? It would describe a two-file program, cost
one small turn of your subscription, and prove the confinement holds against a
real model.

--------------------------------------------------------------------------------

### User Request 12

> 2. Plans a blueprint as issue files, checks the plan itself, and writes every
> issue in parallel. Your own issue validator passes the result.

what does it use to write the issues?

do you have the strategem at /home/ritz/programs/rao-chat/strategem/ that
suggests other people's software be viewed as a rubric?

> 4. Takes change requests in plain words, grades each one (surface, middle, or
> foundation) by how much of the design it would rebuild, and holds foundation
> changes until you say go.

applies changes to issue files, or behavior, or both?

> May I run one real Claude Code turn? It would describe a two-file program,
> cost one small turn of your subscription, and prove the confinement holds
> against a real model.

sure. I don't have many API credits so I prefer using the subscription.

> 1. Reads the code without a model: every file, its language, and which file
> includes which. This runs across all 12 cores and takes 0.6 seconds on the
> 8,500-file AzerothCore tree.

eventually, all we should need to give is a name. In the interim, we can give
compiled binaries and such. For this prototype, source-code is fine.

--------------------------------------------------------------------------------

### Assistant Response 12

> No, the machine doesn't use that strategem, and reading it exposed a real
> flaw. More on that below. First, the live run you approved:

*[commit] 66eca6510 in ai-stuff - Run one real Claude Code turn, and close the harness*

Issue 305 is closed and committed, and your notes about names and binaries are
saved in the vision.

**What writes the issues?** A model, one turn per issue: Claude Code by default,
now proven live. Each turn gets the source files its issue covers, the outline,
and your issue-lifecycle skill file as its guide to the house format. The
machine never writes issue content itself; it only checks what comes back. The
earlier demos used the stand-in, which played back issues I wrote by hand.

**Does a change go into the issue files, the behavior, or both?** Both, always
in that order. First the request is written into the issue files. Then the
design is rebuilt from those issues, only as far as the change reaches. The code
is never edited directly, so the blueprint and the design can't drift apart.

**Other people's software as a rubric:** no, and the machine currently breaks
that strategem in two ways.

1. **It copies answers.** A describe turn writes down everything the source
   does, as one flat specification. It never separates the rules (what must hold
   for anyone: file formats, ordering, what the platform refuses) from the
   choices (defaults, structure, anything that could have been otherwise). So
   the design inherits every choice, which is the "cheating" the strategem warns
   about.
2. **Its referee shares code with the thing it grades.** An issue's acceptance
   command runs a test file, and the build turn writes that test file itself, in
   the same turn as the code it checks. By the strategem's own words, that
   grades nothing: a build turn could write broken code with a test that passes.

**A rough fix, for you to judge before I write any issue:**
- **Describe in two parts per issue:** rules and choices. Build turns keep the
  rules and are asked to make the choices differently ("different each time").
- **Referees come from the rules alone,** written by a separate turn that sees
  neither the source nor the design. The machine proves each referee has teeth
  by running it against a deliberately broken build and requiring a failure,
  like the talent referee in wow-chat.

Here's the hard part, and I'd like your view on it. The source is the only thing
that shows what the rules are, yet the source is also one particular answer. How
can a describe turn tell which of the source's behaviors are rules and which are
its author's choices, when both look the same in code? A second, different
implementation of the same kind of software would expose the difference, since
whatever the two agree on is likely a rule. Is that where "eventually, all we
should need to give is a name" leads? A name would point to many implementations
at once, not one.

--------------------------------------------------------------------------------

### User Request 13

> - Describe in two parts per issue: rules and choices. Build turns keep the
> rules and are asked to make the choices differently ("different each time").

doesn't necessarily have to be different each time. We're looking for
customization, not provenance.

the goal is to be able to say "hello, I'd like my own version of dropbox with
these tweaks" and the system would build it from scratch. The behavior of
dropbox would be understood, and it would be reproducible just from name. Then,
we can create a shared platform (like rmail) that allows people to share and
develop things. You can't copyright a picture, and this gives us memes. You
can't copyright a software, and this gives us these.

--------------------------------------------------------------------------------

### Assistant Response 13

I saved your words to the vision. Understood: customization, not novelty. That
changes what the two-part split is for:

- **Rules** are the behavior that makes it "Dropbox": files sync across
  machines, a conflict keeps both copies, a shared folder shows up for everyone
  invited.
- **Choices** are the knobs. "With these tweaks" becomes a set of changed
  choices, graded like any other request, and most tweaks should land as
  surface-grade.
- **Name-only** means the describe step writes the rules from what's publicly
  known about the software (its documentation and observable behavior) instead
  of from its source. The rest of the machine doesn't change.
- **The shared platform** trades blueprints, not code. Someone's "Dropbox, but
  with LAN-only sync" is a blueprint plus a set of choices, and anyone can build
  their own copy from it.

One correction, because the plan depends on it. Pictures and software code *are*
copyrightable. What copyright doesn't cover is behavior: ideas, methods, and how
a program functions. So the plan works, for a different reason than the one you
gave:
- **Copyright protects expression.** Describing what Dropbox *does* and building
  it fresh is the clean-room method. Phoenix used it in the 1980s to clone the
  IBM PC BIOS legally, and the machine's rule that build turns never see the
  source is that same wall.
- **Patents can cover behavior itself.** Some specific features would be off
  limits regardless of how they were built.
- **Trademarks cover the name.** You can build "your own Dropbox", but you can't
  ship or share it *called* Dropbox. The shared platform would need its own
  names for things. That fits your "never name such a thing".
- **Terms of service** sometimes forbid reverse engineering, which matters once
  binaries become an input.

This isn't legal advice. For memes, the reality is that sharing mostly goes
unenforced, not that it's legally free. Your blueprint platform would stand on
firmer ground than memes do, because behavior really is free to copy.

The referee problem still stands whatever the input is: build turns currently
write their own tests. That needs fixing before anything built here can be
trusted.

A question back: once a blueprint describes behavior rather than code, what
proves a rebuilt "Dropbox" actually behaves like Dropbox? Rules written from
documentation can be wrong or incomplete, and nothing would catch that unless
something compares against the real product. What would you accept as the check?

--------------------------------------------------------------------------------

### User Request 14

> The referee problem still stands whatever the input is: build turns currently
> write their own tests. That needs fixing before anything built here can be
> trusted.

okay

> A question back: once a blueprint describes behavior rather than code, what
> proves a rebuilt "Dropbox" actually behaves like Dropbox? Rules written from
> documentation can be wrong or incomplete, and nothing would catch that unless
> something compares against the real product. What
>   would you accept as the check?

the user is expected to test their own application. The system should make
workflows that use the same types of input that the user would provide, to test
behavior from end-to-end. We don't have to test against the real product, we
just have to describe how it works, and then utilize that description to build
our own to solve the same problem, but in our own way, that is customizable as
we go. Protocols, not procedures.

--------------------------------------------------------------------------------

### Assistant Response 14

> Understood: the check is end-to-end workflows that feed the design the same
> kinds of input a person would, written from the blueprint's description of
> behavior (protocols, not procedures), and the person tests their own
> application after that. Taking your "okay" as the go-ahead to fix the referee
> problem that way. Saving your words, then writing the issue before building
> anything:

> The issue validates. Building it now, starting with the new turn kind, the
> case's `workflows/` folder, and the new ledger kinds:

> While in the case module I spotted a real bug: the person's `input/crafts`
> file (the skills to build with) would have been treated as a change request.
> Fixing that too. Then the workflows module:

> Now the smaller edits to the fixture script, with no nested brackets this
> time:

> Every existing check still passes with referees in place. Now the checks for
> the referee work itself:

*[commit] b57d2ce4c in ai-stuff - Check designs with workflows the builder never sees*

The referee fix is built and committed, and all 12 check files pass.

**How it works now:** before anything is built, a separate turn that reads only
the blueprint (never the source, never the design) writes workflows. Each one
uses the program the way a person would: it types commands, reads what gets
printed, and looks in the files the program saves. The workflows sit in a folder
the builders can't see or write to.

- **A workflow with no teeth is thrown out.** Each one must fail against an
  empty folder; one that passes with nothing built checks nothing.
- **Delivery trusts only the workflows.** The builder's own tests are kept, but
  only as a repair aid.
- **Every change request rewrites the workflows** from the amended blueprint, so
  the rebuilt program is checked against the new behaviour.

**Proof it catches the real problem:** the fixture now has a builder that drops
tags from listings and weakens its own test to match. Its own check passes. The
tags workflow fails it, a repair fixes it, and only then is it delivered. That's
case three of `./run-phase-demo 5`.

**Fixed along the way:** your `input/crafts` file (the list of skills to build
with) would have been read as a change request.

**Not built yet, because you haven't said to:**
- The rules/choices split in issues, for customization.
- Describing software from a name instead of from source.
- The shared platform for trading blueprints.

Your words on all three are saved in the vision.

**A new open question** came out of this work (question 9 in the open-questions
doc). One workflow usually exercises several issues. The tags workflow, for
example, touches tag parsing, showing notes, and the notes command. When it
fails, all three get a repair turn, though only one was at fault. A repair turn
on innocent code can break working code for no reason.

How should the machine decide which one is guilty?
1. **Narrower workflows**, one issue each. This conflicts with end-to-end, since
   a person's action crosses several pieces.
2. **A judging turn** that reads the failure output and the covered issues, then
   picks one, like locating a request.
3. **Repair the highest issue in the build order first**, since it's built on
   the others, and widen only if it still fails.

--------------------------------------------------------------------------------

### User Request 15

<pasted_content id="ea37">
> A new open question came out of this work (question 9 in the open-questions
> doc). One workflow usually exercises several issues. The tags workflow, for
> example, touches tag parsing, showing notes, and the notes command. When it
> fails, all three get a repair turn, though only one
> was at fault. A repair turn on innocent code can break working code for no
> reason.
>
>   How should the machine decide which one is guilty?
</pasted_content id="ea37">


do a small audit of the functionality to ensure that we didn't design it wrong.
If no fixes are required, then the code won't change. Compare a before/after
checksum of just that component, and if it's the same for all three, then
combine them into groups of 2 (if there's one left over, then ignore it, because
it's already been analyzed) and try again. The grouping is to see if there's a
relationship between two of the components, selected randomly. If no, then try
merging again. At this point in the example of three, there'd be one group. We'd
then try and find the flaw in the one, massive group, which is harder, but, this
is what happens when we can't fix it individually, we gotta look at the bigger
picture. Once we identify the part that needs a fix, not what the fix is just
the part that needs it, then we reduce our view again until we're within fixing
range. Then we apply the fix. Dynamic re-abstraction.

--------------------------------------------------------------------------------

### Assistant Response 15

> I read this as your answer to question 9, and as the design to build: widen
> the view only when the narrow look finds nothing, then narrow back to fix.
> Here's how I'll implement it:
>
> 1. **Audit each covered issue alone**, one at a time. The audit turn fixes its
>    own part only if the fault is there. A checksum of the design before and
>    after says whether it changed anything. After each change, the failing
>    workflow runs again, and the audits stop once it passes.
> 2. **If no single audit changed anything:** pair the issues at random (an odd
>    one out is skipped, since it was already audited alone). Each pair gets an
>    inspection turn that only names which part holds the flaw and why. It
>    writes no code.
> 3. **If no pair names one:** merge into bigger groups, and finally one group
>    holding everything the workflow covers.
> 4. **Once a part is named:** narrow back down, and audit that one issue with
>    the finding in hand.
>
> The random pairing is seeded from the ledger's head hash, so anyone holding
> the ledger gets the same pairs. Writing the issue first:

> Now the code: two new turn kinds, two ledger kinds, and the search itself.

> Wiring the search into delivery, in place of repairing every covered issue:

> Now the fixture's audit and inspect turns, with two new switches: a bug that
> no single audit finds (only a wider look names it), and a bug nobody finds.

> Those two failures are expected: the old check looked for repair turns, and
> now it's an audit. Updating that check, then writing the checks for the search
> itself:

*[commit] e37b167c9 in ai-stuff - Find a failing workflow's fault by dynamic re-abstraction*

Dynamic re-abstraction is built and committed, and all 13 check files pass.

**What happens now when a workflow fails:**
1. **Each part it covers is audited alone.** An audit fixes its own part or
   changes nothing. A checksum of the design before and after says which. The
   search stops the moment the workflow passes, so innocent parts are never
   touched after the fix.
2. **If no audit changed anything**, the parts are paired at random (the odd one
   out is skipped), then merged into bigger groups, until one group holds
   everything. These wider looks write no code; each only names the part that
   needs fixing.
3. **The first part named is audited again, alone, with the finding in hand.**
   That's where the fix is made.
4. **If even the widest look finds nothing**, the workflow is recorded as failed
   and the design isn't delivered.

The random order is seeded from the ledger's head, so the same history always
gives the same search.

**Demonstrated in `./run-phase-demo 5`:**
- **Case three:** one audit of 201 fixes the fault, and nothing else is touched.
- **Case four:** the fault is hidden from every part looked at alone. All three
  audits find nothing, then the pair 201+301 names 201, and narrowing back to
  201 with that finding fixes it.

**One decision I made beyond your words:** if an audit changes the design but
the workflow still fails, the machine repeats the single-part audits once more
before widening. My reasoning was that a change means a narrow look did find
something, so the narrow range deserves one more try.

Here's the question that decision rests on: when a narrow fix changes something
but doesn't cure the failure, is that evidence the fault is local and needs
another pass, or evidence the fault spans parts and the view should widen right
away? One could argue either way. Which does your picture of the process say?

Still waiting on your answers: open questions 1–6 and 8 in the open-questions
doc.

--------------------------------------------------------------------------------

### User Request 16

now that we have software that can make software, we should make some "asset
generation utilities" - they can be for different filetypes. So one for .png,
one for .mp4, one for .txt, and various source-code files under .src (language
and version printed at first line of each source-code file) my preferred look is
raylib painting lines and surfaces. Usually black background, or gray. Sometimes
white and vibrant colors, but only if it's mostly not for night. lots of
texturing tricks, like drawing a slightly different color, lighter in 1
quadrant, half and half in two others, and darker in a fourth. But just the line
around the middle, as a visual flair. Lots of charts and diagrams with lines
drawn and arrows pointed there - here. things like an src file with a string at
the beginning that says "language model prompt 14597: something something yadda
yadda." then, a light llm decides what to do with it. "draw a circle? Well, it
looks like I'm being handed a circle, so here I'll hand this to the place that
needs a circle."

let's just plan them out now, ways to create rapid planning structures with
arbitrary inputs and outputs. "hmmm, I gotta take this integer array and this
string of text and create an image off of it? Great!" "so it looks like an
analysis machine, I ran it and I got these results [error error dettected]" "so
it looks like the sheep are out of the barn because they pushed through the
door. Let's make that heavier to move from the other side."

then, with the ability to create software as we please...

we can write a story to ourselves

narrative like a child

learn lessons, see the sovereignty of others, watch mechanisms

study and develop your strategems

--------------------------------------------------------------------------------

*Login expired · Please run /login*

--------------------------------------------------------------------------------

### User Request 17

Base directory for this skill: /home/ritz/.claude/skills/canvas-and-paintbrush

# Canvas and Paintbrush

A method for building **a studio**: the part of a project that produces
the thing you can look at, keeps everything it has ever produced, and
gets better at the job because you told it what you liked.

This describes a machine to build. It doesn't know what your project
makes; its first stage is reading the project to find out. Where the
project owner's standing instructions differ from anything here — where
generated files live, how files are named and numbered, how work is
split into issues, what goes in the scratch directories — their
instructions win, and the apparatus adapts to them.

---

## The vocabulary

Five words the rest of the document assumes.

**Paintbrush** — what you are *allowed* to make it with. An integration
into a particular project: the engine's API, the format's grammar, the
layout the project demands. A **closed** set of legal moves, derived
from the project directory, never invented.

**Canvas** — what you are *asked* to make. The description of the task,
handed to whatever is doing the making.

The pairing is inverted from the usual one, where a canvas is a surface
and a brush is a tool. Here the canvas is the brief and the brush is the
capability, which makes the pair complete: **the canvas says what, the
paintbrush says with-what.** A job needs nothing else to be specified.

**Category** — what kind of thing an artifact is, inside this project.
"dandelion sprite", "title card", "loop transition". The unit quality
gets discussed in, because quality is never discussed globally — it is
always *these* that are looking bad.

**Tier** — how good one artifact is, on a five-step scale, written by a
person or by a machine, both using the same steps.

**The pool** — every artifact ever generated, with its category, its
tier, and where that tier came from. Nothing is ever deleted from it.

---

## Stage zero: read the project before deciding anything

This is what makes the skill general. The apparatus below is fixed; what
flows through it is decided here, by reading, before any file is
written. Ask the project in this order, stopping when the answer is
unambiguous:

| Where to look | What it tells you |
|---|---|
| The founding note (`notes/vision` or equivalent) | The founding intent in the author's own words. Outranks everything below. If it says "out to .gif", the argument is over. |
| The table of contents | The phase structure, and which decisions already have names. |
| `input/` | Existing descriptions, if any. They are canvases already written, and evidence of the vocabulary: extract the words they use rather than inventing a second vocabulary beside them. |
| `output/` | What has already been emitted. Existing artifacts are a decision already taken. |
| `src/` and any per-file description files | What machinery exists to be driven. Read the description files first; open source only when chasing a specific behaviour. |
| `issues/`, including completed ones | The blueprint. A generator may already be specified there and half-built. |
| Earlier studios in the same environment | A previous generator (a gif generator, a sprite tool) is the best worked example there is. Read it before designing. |
| The runtime actually installed | Constrains the encoder. Probe it: which language runtimes and versions (`luajit -v`, `cc --version`), which libraries. |
| What inference the project can reach | Decides whether a machine grader is possible at all. Probe it: a local model server answering on its port, an API key in the environment, a vision-capable model. Don't carry an answer over from another project. |
| What the machine can carry | Cores and memory (`nproc`, `free -g`), a usable accelerator (`nvidia-smi`, `vulkaninfo --summary`). A grader that cannot be run is not a grader. |

**Infrastructure is project-specific.** What one project has says nothing
about the next. Use what is there; if what is needed isn't there, work
out what to add with the person whose project it is. An apparatus
designed around a stack that turns out not to exist is worse than one
designed around none, because the second knows what it is.

**When two signals disagree** — the founding note says one thing and the
input directory another — raise it with the person rather than resolving
it silently. **When the project is bare**, the question is genuinely open
and is asked outright.

## Choosing the artifact

A dispatch table, because a chain of conditionals here becomes a chain
of conditionals in the generated code too:

| What the project is about | Artifact | What owning the encoder costs |
|---|---|---|
| Motion, animation, anything with a time axis | `.gif` (GIF89a) | A few hundred lines. Header, palette, per-frame blocks, LZW. Frozen since 1989. |
| A still raster image | `.ppm`/`.pam`, or `.png` | PPM is a text header then raw bytes — nearly free. PNG written with uncompressed ("stored") deflate blocks costs about a hundred lines: the chunk layout, a CRC-32 and an Adler-32. |
| Sound, waveforms, synthesis | `.wav` (RIFF PCM) | Trivial. Forty-odd bytes of header, then samples. |
| Vector line-work, diagrams, plots | `.svg` | A text format. You are writing strings. Free. |
| A report, a gallery, anything to be read | `.html` | Text. Free, and doubles as the viewer. |
| Terminal motion | ANSI frame sequence, or an asciicast | Text. Free. |
| 3D geometry | `.obj` (text) or `.stl` (small binary) | Both nearly free. |
| Typography | `.ttf` | Expensive: tables, checksums, glyph outlines. Only if the project *is* about fonts. |

- **Take the cheapest encoder that still carries the project's meaning.**
  An SVG that says the thing beats a PNG that says the thing, because you
  can read an SVG in a text editor when it goes wrong.
- **Reject any format needing a dependency you would not otherwise
  have.** A borrowed encoder converts your errors into someone else's
  silence.

## What to build now

The whole studio is rarely needed on day one. Build in this order, and
stop where the project stops needing more:

1. **Always:** the spine (description → wall → model → buffers → encoder
   →
   file) and a viewer. This alone answers "make it output something I can
   look at".
2. **When artifacts will pile up:** the pool — the card beside each
   artifact, the five tiers, the count utility.
3. **When stage zero found inference that can perceive the artifact:** a
   machine grader and algorithm A. Otherwise algorithm B, or ratings by
   hand only.
4. **When exact reproduction is proven** (the same description and seed
   give the same bytes, tested): tier-bought elaboration.

Say which of these you are building, and why the rest can wait.

---

## The paintbrush

The paintbrush is a **closed set of legal moves, published**. Two halves
that must not drift apart:

- **The document half** — every word the project's descriptions may
  speak, and what each one means. A contract, readable by a person.
- **The executable half** — the sandbox table of permitted constructors.
  If the host language can run a description file directly (Lua is very
  good at this), then the language *is* the parser and this table *is*
  the grammar. No parser to write or debug, and real syntax errors with
  real line numbers, for free.

**Closed is the whole point.** A paintbrush is defined by what it
refuses. Hand something a long reference describing an API and it will
invent plausible neighbouring calls that do not exist, confidently and in
good style — true of people working fast and much truer of language
models. A short allowlist has nowhere for the analogy to go. **Prefer a
closed allowlist over a complete reference, most of all exactly when the
temptation to document everything is strongest.**

Where the project already has an interface — an engine, a format, a
layout — the paintbrush is *extracted*, not designed. What exists is the
vocabulary. Adding words the project doesn't have is how a paintbrush
stops describing its project.

## The wall

Between the paintbrush and everything downstream sits a **wall, not a
net**. A net catches some things and shrugs the rest through.

- **Every error is named and located.** Which entry, which field, what
  was wrong. "invalid input" is not an error message, it is an apology.
- **Every error carries the nearest legal word.** The vocabulary is
  closed and small, so edit distance to the legal words is computable and
  one of them is almost certainly what was meant. Say so.
- **All errors are reported together, in one pass.** Stopping at the
  first turns fixing a description into a guessing game, one round per
  run.
- **Nothing is quietly filled in.** A malformed field is an error. An
  *absent optional* field taking a documented default is different — that
  is vocabulary, published in the document half. A default that appears
  in the paintbrush document is vocabulary; a default that appears only
  in code is a fallback, and a fallback is a warning, and a warning is an
  error. If one ever fires, it says so loudly on the way past and gets
  recorded as work to remove it.

---

## The spine the paintbrush drives

A description in, one self-contained artifact out. The properties the
rest of the studio depends on live here.

```
  a written description        text a person can author and diff
        │
  the wall                     refuse early, loudly, all at once
        │
  a compiled model             names resolved to numbers, once
        │
  evaluation                   the model asked one question repeatedly
        │
  buffers                      raw values, not yet a file
        │
  an encoder you own           bytes, to a frozen specification
        │
  one self-contained artifact
```

**Compilation resolves names to numbers exactly once.** If one entry
refers to another — borrowing a landmark, inheriting a colour, continuing
where something ended — that lookup happens at compile time and what
lands in the model is a plain number. The evaluation loop runs thousands
of times and never does a name lookup inside itself.

**Allocate memory first, then work through it.** Whatever the project's
many-small-things are — particles, samples, cells, rays — allocate the
pool once, up front, as **parallel flat arrays**: all the first fields
together, all the second fields together, not an array of records. The
inner loop then walks contiguous memory instead of fetching cache lines
mostly full of fields it isn't using, and a worker thread can later own a
*span of indices* with nothing shared to lock, which makes threading a
loop bound rather than a rewrite.

**Accumulate wide, reduce narrow, deliberately.** Accumulate in floating
point where contributions genuinely add and can exceed any maximum, then
tone-map or limit down to what the format can represent, and **design the
narrow target on purpose** knowing what this project's data looks like. A
generic quantiser is always worse than one built for glowing particles on
black. An accumulator that saturates silently at the output maximum has
destroyed the information that would have said by how much.

**Parallel work merges in a fixed order.** Floating-point addition is not
associative — `(a + b) + c` and `a + (b + c)` can round differently — so
partial sums combined in whatever order the workers finish produce
different bytes on different runs. Give each worker a fixed span of
indices and its own partial buffer, and combine the partials in index
order, never in completion order.

**Write the file format yourself.** Frozen specifications don't move. The
cost is a few hundred lines once, mostly laying out headers in order, and
the palette and sample rate become yours to design. The failure mode is
the real argument: your own broken encoder fails loudly in code you can
read, while a borrowed one falls back silently into a path you've never
seen and produces a file subtly wrong in a way noticed weeks later. If a
system library for the format exists, record in the architecture document
the decision not to use it — an unwritten decision gets re-litigated.

**Test the encoder with a round trip.** Write an independent decoder in
the test file, decode the file you wrote, and check that the decoded
values equal the buffers that went into the encoder *after* quantisation
(the pre-quantisation values will legitimately differ). It is the only
test that catches an encoder that is confidently wrong: a compression loop
that grows its code width one entry late produces a file that *mostly*
works, and only a decoder notices. Where an outside tool can open the
output, run that too. Two independent readers is proof; one is an opinion.

**The same description gives byte-identical output.** The seed is an
explicit, named field of the description, never read from the clock or
the environment. If descriptions may omit it, the default seed is
published in the paintbrush document like any other default. Test it by
running twice and comparing the files byte for byte. This is what lets
tests assert on bytes instead of on someone squinting, and what makes
every rating in the pool refer to something reproducible.

---

## The wall between making and looking

**The program that makes the artifact and the program that shows it are
separate programs that share no code.** The viewer reads only the
finished file, exactly as a stranger would see it — no access to the
compiled model, the buffers or the simulation state.

This is error containment, not tidiness. A bug in one can't hide inside
the other. When the viewer shows something wrong, "is the file wrong or
the display?" is answered by opening the file in a third-party tool, and
the answer is definitive. Share code between them and that question
becomes unanswerable.

The rating interface is a viewer. It shows artifacts and collects tiers;
it never reaches back into the machinery that made them. A grader with
access to the generator's internals grades the intent rather than the
result, and the result is all anyone else will ever see. The viewer is
usually the cheapest thing in the project — a page pointing at the output
directory is often enough — and should stay that way.

---

## The pool

Everything the studio has ever generated, kept.

**Where it lives.** In a persistent directory of the project, never in a
RAM-backed or scratch directory: those are emptied on reboot, and the
pool is the one thing here that can't be regenerated, because the ratings
in it are human judgment. Whether the pool is tracked in git, stored with
git-LFS, or ignored and backed up separately is a decision for the owner
(see the open questions) — thousands of binary files in ordinary git
history is its own problem.

## Nothing is ever deleted

Not the bad ones. A low tier is information — it records what missed and
by how much. Re-rating can promote something mis-scored in a hurry. And a
pool you prune is a pool whose history can't be reconstructed, which makes
every later question about *why the outputs drifted* unanswerable.
Storage is cheap; judgment is expensive. Never throw away the expensive
thing to save the cheap one.

## Five tiers

| Tier | Meaning |
|---|---|
| 5 | Love it. Reach for this first. Show it to people. |
| 4 | Good. Use freely. |
| 3 | Okay. Fine among others, not on its own. |
| 2 | Weak. Kept, not reached for. |
| 1 | No. Kept as the record of what missed. |

## Two ways of rating, and they are different machines

**Build both** when the project needs ratings at all. Which one runs is a
setting, and switching costs nothing because they write the same field.
Select between them by dispatch — a table of two rating machines chosen by
key — rather than a branch inside the rating code, because a branch there
sprouts a second branch and the two designs start borrowing each other's
assumptions. A project may want A for one category and B for another,
which is another reason the choice is a key and not a global mode.

### Algorithm A — rate on arrival, correct on inspection

The machine rates **everything** the moment it exists. A person rates a
little, whenever they feel like it. Both write the same field; the
person's rating wins and is marked as a person's.

It solves an arithmetic problem: if everything is kept and only a little
is looked at, the pool is overwhelmingly unrated, and a floor of "tier 4
or better" excludes nearly the whole library. Rating on arrival means
floors work from the first day. It also pays a second time: wherever a
machine tier and a person's tier exist for the same artifact, that is a
free measurement of **how often the machine agrees with you**, collected
continuously as a by-product of use. A machine grader nobody has measured
is a rumour, not a grader.

**What the grader is, is a project question**, answered by stage zero's
probes. Two constraints bind whatever is chosen:

- **It perceives the artifact as the artifact.** A grader that sees one
  still frame of an animation is rating an illustration. This applies to
  the agent running this skill too: an image-reading tool shows an
  animated GIF as one still picture. So when the agent grades, give it
  motion as a frame strip (a contact sheet of every Nth frame, in order)
  or as per-frame statistics, and give it sound as a spectrogram plus
  numeric features (loudness over time, pitch, onsets). A grading
  subagent can be started without the owner's long-form instructions
  loaded, where the platform allows it, so its judgment isn't coloured by
  them.
- **It answers the same question a person answers, in the same five
  steps.** That is what makes agreement measurable.

**If no adequate grader can be run, algorithm A is not available.** That
is a real outcome: without the grader, A degrades into an unrated pool
with a floor that excludes everything. Find this out before building A.

Its shape: **large pool, thin judgment, measured.**

### Algorithm B — judge the pool once, then curate in use

A person passes over the whole library once and gives everything a tier.
From then on **the rating happens during use**: the moment somebody
working with the thing thinks *that one is wrong*, they change its tier
right there and carry on.

- **Every rating is a person's**, so provenance is uniform. There's no
  agreement rate because there's nothing to compare against — which
  removes an apparatus, and also removes the safety measurement it gave.
- **The judgment happens in context, which is a better question.** In a
  gallery an artifact is judged as a picture; mid-use it is judged on
  *did that do its job, at that size, next to those things, when I needed
  it.* That question can't be asked in a gallery, and it's the one that
  matters.
- **The pool is bounded by patience.** The library is only as large as
  somebody will sit through — a real ceiling, and also where the quality
  comes from.

Its shape: **small pool, complete judgment, contextual.** B has an
architectural consequence: **the rating store must be reachable from the
running program**, because the re-rate happens mid-use. Where the program
is a server, the rating arrives through the same door as every other
command.

Neither is better. **A is for ten thousand generated dandelions; B is for
the forty things that actually show up in the work.** A side-by-side
table is in `reference.md`.

## Every artifact carries a card

Beside every artifact in the pool sits a small plain-text card describing
it, with the same stem and its own suffix:

```
goblin-walk-0042.svg     the artifact
goblin-walk-0042.card    everything true about it
```

The suffix is deliberately not one the project already uses for
documentation (such as a per-source-file description convention), so a
documentation build that collects those files doesn't sweep thousands of
cards into the docs. **The pool is the filesystem**: no database, no
index file, no schema; each entry is two files that travel together.

### What the card holds

The purpose is not only to reproduce this artifact but to **make more
like it**, so parameters are recorded individually and by name, not
rolled into one blob. One fact per line, `key: value`, with repeated keys
for the lists:

| Line | Holds | Why |
|---|---|---|
| `what:` | one line of prose | so a person can tell what this is without opening it |
| `category:` | one string from the project's declared set | every quality query starts here |
| `param <name>:` | one per parameter, each a number, string, or a paintbrush enum word | the axes of variation made visible; turns "reproduce it" into "make more like it" |
| `seed:` | one integer, separate from the parameters | varying the seed alone gives a sibling; varying one parameter gives a variation — different requests |
| `paintbrush:` | name and version | a changed vocabulary makes old and new artifacts not honestly comparable |
| `canvas:` | the brief, inline | tells a bad score from an impossible brief |
| `rating:` | `<tier> <who> <timestamp>`, one line per rating, appended | never overwritten; the current tier is the last line |
| `elaboration:` | `<parameter>=<value> -> <file>`, one line each | the extra work bought by a high tier, traced to this origin |

**Ratings are appended, one line in one write, in append mode.** Under
algorithm A the grader writes at arrival; under B a person re-rates from
the running program; both can hit the same card at the same moment. A
read-modify-write loses one of them. A single short append doesn't, and
it needs no lock.

The **seed/parameter separation** is the load-bearing detail: *same
parameters, new seed* is another one of these; *same seed, one parameter
changed* is this exact one, seen differently. Elaboration runs on the
second, and only works if the parameter is separately addressable.

What this buys: **the history survives** (you can see a machine's guess
sitting under a person's later correction, and the agreement rate is
computed straight from these lines); **queries never open an artifact**
(a request for goblins at tier 4 or better reads cards only — small,
greppable text — never decodes an image); and **nothing gets separated
from its meaning** (two files with the same stem in one directory travel
together, where a central store drifts the first time someone moves one
without the other).

### Counts come from a utility

How many goblins exist at tier 4, how often the machine agrees with a
person, how many elaborations are outstanding — none of these are written
into any document. A small utility walks the cards and reports. A typed
number was true once; a utility is true when asked.

---

## The quality-versus-variety dial

The pool is also **a live asset library queried at generation time**, and
the tier is the filter. The exchange it is built for:

> *"The dandelion sprites are looking pretty bad — can we increase their
> quality?"*
> "Yes. Raising the floor for that category from 3 to 4 leaves 31 to draw
> from instead of 214, so expect them to start resembling each other."
> *"That's okay."*
> "Do you want to look through the unreviewed ones and set some ratings
> yourself?"
> *"No, not now, thanks."*

1. **The floor is per-category and set at run time** — quality is turned
   up on *the dandelions* because *the dandelions* are what's bothering
   you.
2. **Raising the floor costs variety, and the system says so first** —
   the surviving set's size at the current and proposed floor, reported
   at the moment of choosing.
3. **A second dial: provenance.** "Tier 4 or better" and "tier 4 or
   better *as judged by a person*" are different requests; offer both.
4. **Re-rating is offered, never pressed, and declining is free.** The
   offer carries its cost ("31 unreviewed at this floor"). "Not now"
   costs nothing and isn't asked again in the same breath.

Retrieved entries have two uses: **shown to the generator as examples of
what good looks like here**, and **used directly**, because reuse is
cheaper than regeneration and often better.

---

## Tier buys elaboration

The tier is also a budget for *how much more* gets spent on each
artifact. Isometric sprites make it obvious: a sprite is born with one
viewing angle; the highest-rated ones earn eight or sixteen more, while a
tier-2 sprite keeps the one it was born with. Effort concentrates where
quality already is, and the library grows **deeper** rather than wider.
(Per-artifact examples are in `reference.md`.)

- **Cost lands where it is deserved.**
- **The elaboration queue is computed, not stored.** It is every artifact
  whose current tier entitles it to more elaborations than its card
  records — produced by the same count utility, on demand. Promoting an
  artifact from 3 to 5 puts it in the queue by that fact alone; there is
  no separate work-order file to fall out of step with the cards. Show the
  queue's length wherever tiers are shown, so promotion visibly creates
  work.
- **Demotion never destroys.** It stops further investment; the
  elaboration already paid for stays in the pool at the new tier.

## Elaboration extends, never regenerates

Adding an angle to a rated artifact **extends that artifact** — same
description, same seed, one parameter differing — and never re-rolls it.
A regenerated artifact is a different thing wearing the old one's tier,
and a few of those make every tier in the library a statement about
something that no longer exists. Exact reproduction is what makes this
safe, which is why a project that can't yet reproduce an old artifact
byte for byte doesn't offer elaboration until it can.

---

## Learning: the invariant, and the choice left open

**The invariant:**

> Poor examples are filtered away. Excellent ones are elevated.

The floor filters the poor out of what gets used; the tier budget
elevates the excellent. **How a project actually learns is its own
decision** — retrieval, direct reuse, brief refinement, vocabulary
tightening, or training on preferences, with costs listed in
`reference.md`. Two things hold whichever is chosen:

- **The cheapest mechanisms need no training at all.** Retrieval and reuse
  deliver "it gets better as we use it" on day one, and for many projects
  they are the whole answer.
- **Anything learning from a machine grader needs a person anchoring it.**
  Under algorithm A, if a person's ratings become rare, the apparatus
  converges smoothly on *the grader's* taste with no error raised, found
  months later by not liking the output. So a minimum fraction gets a
  person's rating, and the agreement rate is shown where it can be seen.
  Algorithm B can't fail this way.

---

## How to build it: parallel uniform descent

Build all the components at once, at the same level of abstraction, and
lower that level across the whole system in passes.

- **Pass zero** is one document: the entire dataflow in pseudocode, every
  component present and none detailed. If the project already keeps a
  dataflow or datapath document for each feature, pass zero *is* that
  document — don't write two.
- **Each later pass expands every part by one level**, never one part to
  completion while another is still a sentence.
- **The final pass is running code.**

**Why uniform descent**, mechanically: an interface between two
components is decided at whatever level of detail both sides are at when
they meet. Finish one first and its interface is concrete, so everything
else must accommodate whatever it happened to do, at the cost of a
refactor. Keep everything level and every interface is negotiated while
both sides are still a sentence, where changing it costs a sentence.

The document and the program become the same artifact at different
levels of expansion; the pseudocode is pass zero of the thing itself, not
a plan that goes stale. **Don't stop descending early** — the pass where
it's *almost* code feels finished and isn't. A level that hides a
decision behind a phrase still has that decision unmade.

## The language at the bottom

**Ask: does the hot loop need real parallelism, or only concurrency?**

| Shape | Example | Parallel? |
|---|---|---|
| Many independent jobs from one brief | Generating N candidates | Fully. Each touches nothing another touches. |
| One artifact evolving along its axis | Stepping a simulation forward | No. Each step depends on the last. Say so plainly. |
| Independent finishing work on finished pieces | Encoding frames already computed | Fully. The producer-then-workers shape. |

If the heavy work is only the middle row, the project keeps whatever
language it has. If the first or third row carries the cost — usually,
since those scale with how much you generate — the question is whether
the runtime gives **real operating-system threads over shared memory**. C
does, directly: the flat-array pool exists so a worker takes a span of
indices and touches nothing anyone else touches. A coroutine runtime gives
concurrency but not parallelism, and reaching real threads from one costs
a library, a serialisation boundary, or both. C at the bottom is a
conclusion some projects reach and others don't; only the hot inner work
is ever in question.

**File layout.** A single-file core is fine while it can be read whole;
read it whole or not at all, because in one translation unit a fragment
hides the declarations and lifetimes its meaning depends on. When it no
longer fits in one reading, split it. How the project's files are
numbered and ordered for reading is the project's convention (the
documentation-refactor skill covers renumbering), and keeping a Lua and a
C version of the same core side by side is the polyglot-source skill's
subject.

---

## Failure modes worth knowing before they happen

The full table is in `reference.md`. The ones that aren't obvious from
the sections above:

| Symptom | What is actually wrong | The fix |
|---|---|---|
| Output differs between runs only when threads are on | Partials merged in completion order | Fixed spans, per-worker buffers, merged in index order. |
| A one-off flag appears on the command line | The paintbrush was missing a word and someone routed around it | Add the word to the vocabulary and the document. Flags don't compose. |
| The paintbrush document and the sandbox disagree | The vocabulary has two homes | The document is the contract; derive the table from it, or test them against each other. |
| One component is finished and the others are prose | Uniform descent abandoned | Bring the rest up to that level before going further down. |
| The pool vanished after a reboot | It lived in a scratch or RAM directory | A persistent project directory. |
| Two ratings at once, one lost | Read-modify-write on the card | One-line append in one write. |

---

## Open questions to put to whoever invoked this

Ask only the ones stage zero couldn't answer, one at a time, most
consequential first. Each changes the shape of what gets built.

1. **What does this project emit, in the author's words?** Confirm what
   stage zero found. If it found two answers, settle that first.
2. **Does a studio already exist here in partial form?** Half a studio in
   a document or a completed issue is something to extend, not duplicate.
3. **What are the categories?** The units quality will be discussed in;
   wrong categories make the floor useless.
4. **How much of the studio is wanted now?** The spine and a viewer only,
   or the pool and ratings too (see "What to build now").
5. **Which rating machine, and is it the same for every category?**
6. **Where does the pool live, and is it tracked in git, stored with
   git-LFS, or ignored and backed up?**
7. **What does a higher tier buy here?** If there's no axis of
   elaboration, tier is a filter only — say so.
8. **What is the axis of the artifact itself?** Time, sequence, depth,
   frequency. Often assumed to be time when it isn't.
9. **What units does the description speak, and to what precision?** A
   format measuring delays in hundredths of a second can't honestly
   accept thirty frames per second.
10. **Who rates, how often, and what is the human floor?**
11. **How do the passes of uniform descent map onto the project's issue
    files** — one issue per pass across all components, or one issue per
    component with a sub-issue per pass?
12. **What is the visible proof?** The demo is part of the deliverable;
    decide what it shows before building toward it.

--------------------------------------------------------------------------------

### Assistant Response 17

> Planning, not building. First, stage zero: checking what this machine actually
> has, since that decides the plan's shape.

> Docs for all three phases are written. Now the issue files for phases 8, 9,
> and 10:

> The issues validate clean. Issue 1003 says `strategems/` already holds the two
> strategems this project's own building taught, and you asked to study and
> develop them. Writing those two now:

> Now the roadmap, table of contents, and the open questions this plan raises,
> then the commit:

*[commit] 00560be3e in ai-stuff - Plan the studio, the switchboard, and the story*

The plan is written and committed. Nothing is built yet, as you asked.

**Phase 8, the studio:** one small generator per file kind, all painting in your
look.

| Kind | How it's made |
|---|---|
| `.png` | raylib paints lines and surfaces in a hidden window; our own code writes the file |
| `.mp4` | the same painter, frame by frame |
| `.txt` | tables, lists, and boxes-and-arrows made of line characters |
| source files | written by a model turn; the first line names the language and version, and the language's own parser checks the file |

- **The look lives in one table:** black or gray ground, white and vibrant only
  when not for night, the four-quarter flair on each surface's middle line only,
  and arrows labelled at both ends ("there → here").
- **Charts and diagrams are words in the vocabulary**, not separate tools. The
  first things to draw are the machine's own blueprint graphs, centers, and
  ledgers.
- **Each asset is described in a small closed vocabulary.** An unknown word is
  refused and the nearest legal one is named.
- **Every asset is kept** beside a card of facts and a 1–5 rating, viewed in a
  raylib gallery.

**Phase 9, the switchboard:** your "language model prompt 14597:" files.
- **A light local model (ollama) does one job:** name what a parcel is and which
  station it goes to, like "I'm handed a circle, so it goes to the place that
  needs circles." The machine checks that answer against the station table.
- **Multi-step jobs are planned by input and output type**, so "integer array +
  text → image" becomes a chain of stations.
- **Results that report an error become a change request** against the mechanism
  at fault ("make the door heavier"). The existing update machinery handles
  those.

**Phase 10, the story:** each case's ledger told back as plain chapters, naming
whose each thing was. Lessons come from the turning points, each naming a
mechanism. A strategem is drafted when a mechanism recurs, and you decide
whether to keep it.

**Studying the strategems:** I wrote the two that this project's own building
taught, a referee never sees the answer and dynamic re-abstraction, in the
rao-chat form.

**Five new open questions** are recorded (10–14 in the open-questions doc).
The most consequential first, since the rest of the studio leans on it:

Owning a file format is your house rule, but `.mp4` needs an H.264 encoder,
which is a whole codec, not a few hundred lines. The plan hands our own
byte-exact frames to ffmpeg for the `.mp4`, and writes every clip as a `.gif`
with the house encoder too, so one path never borrows bytes. Is that acceptable,
or would you rather the studio make only `.gif` clips?

--------------------------------------------------------------------------------

