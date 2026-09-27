# Conversation Summary: e8e4c82c-c417-4a78-b8c0-ac2908436973

Generated on: 2026-09-27 12:00:49
Models: claude-opus-5-5

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

