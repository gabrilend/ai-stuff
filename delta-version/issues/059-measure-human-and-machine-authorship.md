# Issue 059: Measure Human and Machine Authorship

**Status**: In progress (built and tested; not yet a README slot; open questions below)
**Priority**: Medium
**Created**: 2026-09-23
**Type**: New measuring instrument (`scripts/measure-authorship.lua`)
**Related**: `058-front-page-rewrites-its-own-figures.md`, which wires this
into a README slot. It replaces the front page's hand-kept claim that
`hero-less-moba` "has had more work in the last three months than anything
else here".

---

## Current Behavior

**Built (2026-09-23).** Steps 1–9 are in place:

- `scripts/measure-authorship.lua` produces the four figures from both
  halves, conversations and the repository's tracked files. It takes about
  three seconds with twelve workers and gives the same answer with one.
- `scripts/test-measure-authorship.sh` passes 30 of 30 checks.
- The rules as tables are in `scripts/measure-authorship.info.md`. For the
  current figures, run `measure-authorship.lua`, and use `--largest` to see
  which files dominate each pile. They are not copied here, because they
  would go stale.

The repository walk's rules were tuned against `--largest`, one leak at a
time. Each of these first landed in the wrong pile:

- transcript backups (`llm-transcripts-backup/`);
- a 3 MB `README-3.md` that holds a conversation backup pack;
- `.bak` copies;
- a generated archive of word-cloud pages (`archive/`);
- an installed `luarocks` tree;
- a web page saved from a browser.

Separately, the first run showed that `wait` hides a crashed worker. Five
workers died on tracked directories (git links), and the totals came out
short with no error. Every worker now ends its output with a `#finished`
line, and a missing line stops the run.

Findings from the transcript survey that changed the design from the first
draft below:

- **Who sat in the user's chair.** A session id `agent-…` is a sub-agent,
  and its prompts are the machine's. Every other session is the person's,
  including the `<date>_agent-<n>.md` runs with ordinary session ids. Those
  were set aside for a while as a script's `claude -p` runs, because their
  prompts open "Hello computer, all is well." and carry a whole issue file.
  The owner's answer (below) removed the only evidence for that, and a file
  name is the exporter's label, not evidence of who typed.
- **Skill instructions are tool-inserted.** They arrive as user turns
  ("Base directory for this skill:", or a `# … Skill` heading) and are set
  aside.
- **Wrapped logs arrive in pieces.** The exporter re-wraps pasted logs into
  one-line paragraphs that look like nothing on their own. A log therefore
  spreads to neighbouring blocks that are not sentences. A block ending in
  "?", or holding six plain words in a row, is always the person's.
- **Replies between quotes are the person's.** Once quoted `> ` lines
  counted as pasted output, the "between two logs" rule swallowed whole
  paragraphs where the owner answered two quoted excerpts. It now absorbs
  only blocks under 60 characters, which are labels like "The output
  was:".
- **Recursive exports have no separator.** They start an embedded
  conversation straight after an answer, so a conversation heading now
  ends the open turn. Without this, one answer swallowed the next
  conversation, 24,026 characters instead of 1,933.

Not yet done: the census slot that puts the figure on the front page. That
belongs to issue 058.

**Before this issue** — nothing measured how the repository's writing
divided between the person and the machine. Every conversation that built the repository is saved as a
markdown transcript in an `llm-transcripts/` folder: at the repository root
and in each project that keeps one. Nobody has totalled them.

The transcripts are not a clean set to count:

- **One conversation can sit in several files.** The same session gets
  exported into more than one project's folder. A day's file and a
  date-range file cover the same turns. One early risc-v-university
  conversation was exported at five levels of detail (`v1-compact` to
  `v5-raw`), and its opening message appears 81 times across the tree.
  `delta-version/llm-transcripts/FULL-TRANSCRIPT-EXPORT.md` concatenates
  others again.
- **Not every "user" turn was typed by the person.** The tool itself writes
  some of them: sub-agent warm-ups ("Warmup"), the summary that continues a
  compacted session, local-command output, task notifications, and the
  caveat placed before local commands. In sub-agent transcripts (session id
  `agent-…`), every user turn is a prompt that the main model wrote.
- **Some typed turns are pasted logs.** Error output, stack traces and
  terminal dumps were pasted in so the model could read them. The person
  did not write them.
- **Some files are not transcripts at all.** Examples are `wordcloud.md`,
  `robot-analytics.md`, and the older `<uuid>-v3/v4/v5` exports whose
  conversation section is empty.

## Intended Behavior

One command prints the front page's four figures (the owner's wording:
"human written text, machine written text, then amount of sourcecode
generated, then amount of docs generated"):

- **Human-written text** (`human_written_total`): everything the person
  put into the conversations, plus everything under any `notes/` folder,
  which the owner counts as hand-written. Pasted material counts, because
  pasting implies having read it. The exceptions are a pasted error, log
  or program output.
- **Machine-written text** (`machine_written_total`): everything the model
  wrote in the conversations.
- **Source code** (`source_characters`): the program source git tracks,
  less someone else's code.
- **Documents** (`docs_characters`): the documents git tracks, issue files
  included, less notes, transcripts and generated copies.

It also prints how much was set aside and why, so the rules can be
inspected rather than trusted:

    measure-authorship.lua              # terminal summary
    measure-authorship.lua --json       # for the census and other programs
    measure-authorship.lua --largest    # the biggest files in each pile
    measure-authorship.lua --dir=/path  # measure a checkout elsewhere

### The repository's piles

- **Scope.** Only tracked files are read (`git ls-files`).
- **The piles.** The first matching rule decides:
  1. someone else's work is set aside;
  2. copies, transcripts and generated HTML are left out;
  3. `notes/` goes to notes;
  4. `input/`, `output/`, `backups/`, `archives/`, `archive/` and `source/`
     are left out;
  5. markdown, and `.txt` under `docs/` or `issues/`, go to docs;
  6. source extensions and `#!` scripts go to source.
- **Someone else's work** follows the COPYRIGHT file's own rule: the
  nearest licence file, and the file's own header. A licence or header
  naming another rights holder, or granting MIT or Apache terms, marks the
  work vendored. So do the top-level `libs/`, package-manager folders, and
  browser-saved pages.
- **Why not every `libs/`.** Treating every `libs/` folder as vendored was
  considered and rejected: most projects' `libs/` hold code written here.
- **Copies.** Identical contents in several places are counted once.

**The unit is characters on both sides.** The transcripts do not record
token counts, and counting tokens would need the model's tokenizer. Both
sides are counted the same way, so the ratio compares like with like:

- a character is one UTF-8 code point;
- each run of whitespace counts as a single character, because the
  exporter re-wraps lines and that must not change the count.

### Counting rules

| Turn | Credited to |
|------|-------------|
| `### User Request` in a main session, typed prose | human |
| same, a paragraph or fenced block that is a pasted log | set aside as pasted log |
| `### User Request` that is tool-generated (warm-up, command output, task notification, caveat, interruption notice) | set aside as system |
| `### User Request` that continues a compacted session (the model's own summary) | machine |
| `### User Request` in a sub-agent transcript (a prompt the main model wrote) | machine |
| `### Assistant Response` (including its `>` interim lines) | machine |

**How a pasted log is recognised.** A user turn is split into blocks: each
fenced code block is one block, and so is each paragraph between blank
lines. A block counts as a pasted log when either:

- it contains a strong signature: `Traceback (most recent call last)`, Lua's
  `stack traceback:`, a JavaScript `at fn (file:line)` frame, or a line
  that opens with `error:` / `Error:` followed by a `file:line:` location;
  or
- at least half of its non-empty lines look like log lines: a
  `path.ext:123:` location, a leading timestamp, a leading
  `[ERROR]`/`WARN`/`INFO` level, a compiler caret line, or a shell prompt
  (`$ ` or `user@host:`).

A sentence that merely mentions an error is prose and stays human.

**How duplicates are removed.**

- Each user turn gets a key. The key is its text, normalised, joined to the
  normalised text of the two user turns before it in the same
  conversation.
- The chain restarts at every conversation boundary: a
  `# Conversation Summary:` header, a `## 📜 Conversation` heading, or a new
  file.
- Every copy of a conversation therefore produces the same keys, whichever
  file it sits in. The same short message ("continue") in two different
  conversations gets different keys.
- A key is counted once. If copies disagree, which happens when they were
  exported at different levels of detail, the longest assistant response
  seen for that key is used.
- Sub-agent turns are keyed in their own namespace, so a model-written
  prompt can never be deduplicated against a person's message.

## Suggested Implementation Steps

1. **Find the files.** Collect every `*.md` under any `llm-transcripts/`
   folder in the repository, skipping `.git`, `.patches` and `.bak` files.
2. **Parse, in parallel.** Split the file list into one shard per CPU core.
   Run one worker process per shard (`--worker`), all at once. Each worker
   parses its files and writes one record per turn to the RAM tier:
   - the class;
   - a 64-bit hash of the key (two 32-bit FNV-1a passes with different
     seeds);
   - its human, machine, pasted-log and system character counts.

   LuaJIT has no threads, so processes are the parallel unit.
3. **Merge.** The parent waits for every worker, then folds the records by
   hash: first copy for the human side, longest copy for the machine side.
   It totals the result.
4. **Render.** A terminal renderer and a JSON renderer, separate from the
   counting.
5. **Test.** Add `scripts/test-measure-authorship.sh`, which runs fixture
   transcripts in `/dev/shm`. It checks:
   - prose is human;
   - a pasted traceback is set aside;
   - a system turn is set aside;
   - a sub-agent prompt is machine;
   - a conversation copied into a second file is counted once;
   - a longer rendering wins on the machine side;
   - "continue" in two different conversations counts twice;
   - wrapping text at a different width does not change the count.
6. **Document.** Add `measure-authorship.info.md`.
7. **Recognise pasted program output.** Box drawing, progress bars, quoted
   `> ` lines, `[user@host]$` prompts, emoji-led status lines, aligned
   columns and bare paths join the log shapes. Test both directions: the
   output is set aside, and sentences that mention paths, percentages or
   emoji stay the person's.
8. **Walk the repository, in parallel.** List tracked files with
   `git ls-files -z` and find vendored folders from licence files. Classify
   each path, then count contents in `--count-worker` processes: binary
   check, `#!` check, header notice check, conversation check, content hash.
   Merge by hash into piles.
9. **Test the piles.** Build a fixture git repository in `/dev/shm` with
   one file per rule, including an untracked file, a duplicate and a
   binary. Check each pile, and check that one and five workers agree.

## Answered questions

- **Does the person type "Hello computer, all is well."?** It opens 56 user
  turns, most of them templated prompts carrying an issue file, 52 of them
  in `_agent-<n>.md` files. The owner answered (2026-09-23): "Only I ever
  type that, as far as I know."
  - Result: the greeting is not a system opening.
  - The `_agent-<n>.md` runs with ordinary session ids are no longer a
    separate "scripted" origin, since nothing else shows a script wrote
    them. Their prompts are the person's.
  - A template the owner wrote is the owner's writing.
  - The `test_owners_greeting_is_human` test holds this in place.
- **Should pasted program output that is not an error count as the
  person's?** Examples are a pipeline's status lines, or a box-drawn report
  being commented on. The owner answered (2026-09-23): "ideally, no, but
  good luck recognizing it."
  - Result: program-output line shapes were added beside the log shapes
    (step 7).
  - Measured against the real transcripts, the set-aside total went from
    about 100k to about 410k characters.
  - The first attempt also swallowed the owner's replies between quoted
    excerpts. That is fixed and covered by tests.
- **What should the front page report?** The owner: "human written text:
  1234, machine written text: 1234, then amount of sourcecode generated:
  1234, then amount of docs generated: 1234. The docs should include issue
  files. Things in notes/ directories should be human written."
  - Result: the repository half and the four `*_total` / `*_characters`
    fields.

## Open questions

- The fullest rendering of an answer includes the files the model wrote
  (the risc-v-university `v4-complete` export), but ordinary transcripts do
  not. Should file contents be stripped from the few renderings that have
  them, so every conversation is measured alike? Or should the ordinary
  transcripts be re-exported with file contents included?
- "Source code generated" and "docs generated" count everything tracked,
  whoever wrote it. Most of it was written by the model through its editing
  tools, but some was typed by the owner, and git does not say which. Should
  commits carrying the model's co-author line be used to split them?
- `notes/` counts as hand-written wherever it sits. Some notes folders hold
  things the owner did not type: saved conversations (those with exported
  turn headings are left out), or a CLAUDE.md history. Should any be
  excluded by name?
- A skill whose instructions open neither with its directory nor with a
  `# … Skill` heading is only recognised if its opening sentence is listed
  (the design-lead prompt is). Should the exporter mark skill injections
  instead, so no list has to be kept?
- Should the model's compaction summaries count as machine writing, or be
  set aside? They are model-written, but they restate the conversation
  rather than adding to it. They are counted as machine for now.
- Tool calls and their results are not in the transcripts, so file contents
  the model wrote through its editing tools are not counted. Those can be a
  large share of what it produced. Should the count also measure lines
  added to git by commits that carry the machine's co-author line?
- Should an estimated token figure be reported beside characters? One
  token is roughly four characters of English. It is left out because it is
  an estimate, not a count.
