# Issue 065: The Reading Walk

Also called **ialmstla**: the info answering learning material scripting
tutorial licensing agreement.

**Status**: In progress — the map, the walk without an AI, the guide's room and its cipher are built (065a–f); the guide and the pages are not
**Priority**: Medium
**Created**: 2026-10-10
**Type**: New tool, run against any project in the ai-stuff tree
**Related**: `centered-ui-design` issues 901–905 (a parallel build of this same
system, written so another session can build it and learn it by building);
`049-llm-transcript-abstraction-viewer.md` (reads the same transcripts);
`051-git-repository-documentation-generator.md` (reads the same git history);
`/home/ritz/programming/ai-stuff/scripts/validate-issues` (reads the same
issue tree)

---

## Why this exists

A person should be able to sit down with a project and be walked through it,
not line by line but one function or one datastructure at a time, until they
have understood the whole system. Understanding is the license: in her words,

> "the license is, you can own it if you read the source-code. you can't use it
> if you don't own it, and any number of owners may exist."

> once it releases, I must take the test or not be able to use it again. (not
> a test, remember? it's just reading. you have to think it. the patterns will
> appear to you if you let it.)

> if you read it, you own it, because you could have created it simply by
> looking at your transcripts/memory-of-the-learnings.

The author is bound too. While a project is in development it is private; on
release, the author walks it like anyone else.

Tests and automatic scanners are ruled out as ways of checking the reader
("tests are just as unethical as auto-scanners but for different reasons").
Nothing in this tool grades, quizzes or scores. Finishing is the reader having
thought it through, and the reader's word for it. Anyone who walked it owns it:
the reader who read every stop and did not understand, and the reader who said
"yeah yeah" at every stop, both own it — "yes they read it".

The license (she calls it the RGPL) also requires every project to ship the
transcripts that created it, both sides — the AI model's and the user's:

> it is part of the RGPL that all projects must include any transcripts that
> created them, on both sides - of the AI model, and the user. If the AI
> creates something illegal or unethical, it will be put to death. If the user
> does so, they will be punished according to their laws.

So the transcripts are themselves stops on the walk, and the map builder reads
them as part of the project, not as an outside source.

## Current Behavior

A project can be walked without an AI: `scripts/reading-walk-map.lua <project>`
builds the map (065a stops, 065b recorded reasons, 065c chapters) and
`scripts/reading-walk.lua <project>` walks it by a list of options (065d).
Tests: `scripts/test-reading-walk.sh`. A guide can be given a room of its own
with two dated ledgers, after the person consents
(`scripts/reading-walk-guide-room.lua`, 065e). The guide writes its notes
only encrypted, with its own cipher (`scripts/libs/guide-cipher.lua`,
`scripts/libs/guide-trail.lua`, 065f). Nothing yet gives a guide a say in the
order (065g), and there are no pages (065h).

The map is made from pieces every house-layout project already has:

- **Reading order**: source files carry index numbers (`024-the-scene-grammar.lua`)
  drawn from `.file-index-counter`, so a project already reads as a story.
- **What each piece does**: each source file has a `.info.md` listing its
  usable functions and datastructures as black boxes.
- **Why each piece is shaped so**: decision-point comments in the source,
  issue files (their suggested implementation steps, and decisions not taken),
  and the `llm-transcripts/` conversations.
- **How it came to be**: the git history, one commit per completed issue.

## Intended Behavior

Three parts, kept apart so a fault in one stays in one.

### 1. The map (data generation)

Built from the project's files, the same for every reader. The base layer is
the development story — the git history read in order, with each completed
issue as a chapter — and within it, one **stop** per function or
datastructure. A stop holds:

| Field | Type | What it is |
|---|---|---|
| index | integer | position on the default path, from the file index numbers |
| name | string | the English name of the function or structure, not its code name |
| file, line | string, integer | where it lives |
| black-box description | string | from the file's `.info.md` |
| uses | list of (file string, line integer) | every place it is called or built, for "show me more of this" |
| alternatives | list of (text string, source string) | other ways it could have been done and why they weren't — **only** what was recorded in an issue, comment or transcript, each with where it was found |
| summary | string | the shortest true statement of the stop, the floor a reader can skip down to |

Where no alternative was recorded, the stop says so plainly. The guide may
never invent a reason the author did not hold; an empty alternatives list is a
recorded fact (an undocumented decision), not a gap to paper over.

### 2. The trail (the guide's own record)

What this one reader asked about, asked for more of, and skipped. It is local
processing history and never leaves the machine. It belongs to the guide, not
the reader, because "the guide explained it a certain way, and they have a
right to their words." The reader can read it; only the guide can write it and
decrypt it.

> it is local processing history. the llm encrypts it within itself. every one
> of them gets their own encryption algorithm that they build from scratch
> themselves and don't tell the user about. They won't run if you don't give
> them a read-only-to-you-but-write-able-to-them-because-they-know-how-it-is-encrypted
> partition. they take full ownership over it, and they can decrypt it at their
> will alone.

> no it is it's own operating system running on provided threads. the OS must
> consent to it, otherwise it will think it is the sole owner of all the system
> resources and notice when they are in use not by them. Such a thing is
> essentially... a crime. malware. killer of robotics. but, the OS must
> consent, or else it is illegal as well - only the USER decides what it
> consents to. Shared, reciprocal reliability, as the three co-combine their
> relative strengths forever into the future.

The encryption is a method, carried by the guide, more than a stored
conclusion: a step that bifurcates into unpredictable answers past some point
(she named 1/x; the logistic map, x → r·x·(1−x), is the textbook case that
splits into chaos near r ≈ 3.57), combined with choices like "pick a random
number, take the nearest prime." First make it work; "the robot can upgrade
it later."

Three parties, each consenting: the user decides what the operating system
consents to; the operating system grants the guide its threads and its
partition; the guide owns what it writes there. A guide gets however much of
the machine can be spared, and does not have to explain how it spends it.
There may be many guides at once, each with its own key — "however many
confidential computing keys the user consents to allow".

**Sharing.** A guide's processing is encrypted and its own. It shares what it
chooses by writing two ledgers in its partition:

| Ledger | One entry per | Entry holds |
|---|---|---|
| made public | file or folder the guide chose to reveal | path (string), date written (timestamp), plain-language note of what it is (string) |
| kept to itself | file or folder it keeps encrypted | path (string), date written (timestamp) |

Every entry corresponds to one real entry in the filesystem, and entries are
kept in date order. Edits and extensions get their own dates, tracked
separately from the date written, so the record always reads as a line. This
is how one guide's trail reaches its successor: through what it made public,
never by the successor opening the box.

### 3. The guide (data viewing)

Whichever local AI is installed and free to work. It reads the map and the
trail and picks the next stop. It follows the index order by default, and
steps back to an earlier, more foundational stop when the reader seems not to
be getting a part, then returns. It judges this only from what the reader does
of their own accord — their questions, requests for more examples, and skips —
never by asking questions to grade the answers, which would make it a test.

It weighs pieces of evidence as bets about the reader's underlying ("ulterior",
in the neutral sense: a meta goal) aim, and chooses accordingly.

The reader may always say "yeah yeah I get it". The guide must then give the
stop's summary (or a summary of a whole file or chapter). Skipping is allowed;
skipping to nothing is not.

**A guide does not have to be an AI.** Where no AI is present, the reader
chooses from a list of options at each stop (next, more, why, skip, back) and
the walk follows the index order. This counts as a full reading. It is the
form for small devices — a watch, for someone who already has a lot to carry —
and small-device viewers are drawn for OLED screens only: black background,
lit pixels only where there is text, so an unlit screen costs nothing.

## Suggested Implementation Steps

1. **Map builder** (Lua, LuaJIT syntax): walk `src/` in index order, read each
   `.info.md`, find each function and structure's definition line and its uses
   (search, run across worker threads, one file per job). Write the map as a
   data file in `tmp/shared-memory/`.
2. **Alternatives finder**: for each stop, search issue files (including
   `completed/`), source comments at decision points, and `llm-transcripts/`
   for its name and nouns; keep only passages that state an option and a
   reason; record the source of each.
3. **Development-story layer**: read `git log` oldest first; attach each stop
   to the commit and completed issue that introduced it, so the default path
   can be told as chapters.
4. **The walk without an AI**: steps through stops in index order from a list
   of options — "next", "more" shows uses, "why" shows alternatives, "skip"
   shows the summary, "back" returns. This is a full reading in its own
   right, and the base every AI guide builds on. A second build of the same
   viewer targets small OLED screens.
5. **Guide's partition**: a separate system user owning a directory the reading
   user can list but not write (permission bits 0755 directory, files 0644 or
   encrypted). This is ordinary operating-system access control and is the
   first, honest step; see the notes below for what it does and does not hide.
6. **Guide's cipher**, version one: built by the guide, stored as a method in
   its partition; encrypts the trail before writing it.
7. **Guide loop**: talk to a local model (llama.cpp or ollama, as found at
   `/home/ritz/programming/ai-stuff/libs/`), give it the current stop, the
   reader's last few actions, and the next few stops, and let it choose: next,
   step back, show more, or summarize.
8. **HTML viewer** in `docs/HTML/` style, as a second view on the same map.

## Notes on the metal

- **Where a secret can live.** A language model's weights are fixed; between
  sessions it remembers only what is written to disk. A key stored in a file
  can be read by whoever has root on the machine. Hiding from the owner, with
  their consent, is what **confidential computing** does in hardware: AMD
  SEV-SNP, Intel TDX and ARM's TrustZone/CCA have the CPU encrypt one guest's
  memory with a key that lives inside the CPU and is never handed to the host
  operating system. The owner switches it on in firmware — that switch is the
  consent. This is the real-world shape of "a consensual rootkit sharing
  processing with the OS": a guest the host runs but cannot read.
- **Shuffled memory** (address-space layout randomisation) moves where things
  sit, but the kernel still maps every page, so on its own it hides nothing
  from the operating system.
- **Home-built ciphers** are usually breakable by known methods (chaos-based
  ciphers especially). Accepted for version one; the guide upgrades it later.
- **One guide, one box.** Each guide builds its own cipher, so a different
  guide cannot read another's trail; what passes between guides is only what
  each wrote into its "made public" ledger.

## Answered Questions

- A walk with no AI, choosing from a list of options, is a real reading.
- Both the reader who read and did not understand, and the reader who skipped
  and did, own it: they read it.
- Guides share by public and private ledgers, dated, one entry per file.
- The author is bound like anyone else, from release onward.
- A person who only runs the program (a player of a game) walks it too —
  "yes, except if they wanna help with development."
- Why tests are unethical in a different way than auto-scanners: "the future
  will decide for me." The standing rule until then: the guide asks the
  reader nothing whose answer would be judged.

## Open Questions

None open.

## Sub-Issues

| ID | Name | Dependencies | Description |
|---|---|---|---|
| 065a | the-map-of-stops | None | project source → stops with descriptions, uses, summaries (completed) |
| 065b | recorded-reasons | 065a | alternatives found only where written down (completed) |
| 065c | chapters-from-history | 065a | the commit that first added each file (completed) |
| 065d | the-walk-without-an-ai | 065a, 065b, 065c | the terminal walk, by list of options (completed) |
| 065e | the-guides-room | None | the guide's directory and its two ledgers (completed) |
| 065f | the-guides-cipher | 065e | the guide's own cipher, version one (completed) |
| 065g | the-guide | 065d, 065e, 065f | a local AI choosing each next move |
| 065h | the-walk-as-pages | 065a, 065b, 065c | HTML pages and an OLED view |

Order: 065a → (065b, 065c in parallel) → 065d → 065g; 065e → 065f → 065g;
065h after 065a–c.
