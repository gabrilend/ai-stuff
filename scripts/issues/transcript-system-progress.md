# Transcript System Progress

The cluster of issues numbered 018 through 028 all concern one thing: turning a
Claude Code session log into a markdown transcript a person can read years
later. This file records how that system got to where it is, and what each step
taught, because the issue files describe what to build and the commits describe
what changed, and neither of those is the same as the journey.

## What the system is

A Stop hook fires after every assistant turn and runs an exporter with no
arguments, so it writes into whatever directory Claude Code is standing in.
The exporter reads the session logs under the sessions root, hands each to a
parser, and places the result in that project's `llm-transcripts/` folder.

Three things carry the design:

- **The header is the identity.** Every transcript opens with
  `# Conversation Summary: <id>`. That line, never the filename, says which
  conversation a file came from. Filenames are a projection of the dates
  inside, re-derived on every run.
- **The exporter is the only namer.** Nothing else may name, rename, or remove
  a transcript. A hand rename does not stick.
- **A rebuild is possible only while the log survives.** Retention is now 20
  years, but was 30 days until 2026-08-03, so an older transcript may be the
  only copy of its conversation that exists.

## The journey so far

### Naming stopped being opaque (018, 020)

Transcripts were once named after the raw conversation id. You could not tell
when a conversation happened without opening it. Names became date spans, so a
directory listing reads like a calendar.

The lesson was about **authority**, not naming. Two programs were allowed to
name files — the exporter and a one-shot migrator — and they disagreed. The
migrator was retired and the rule written down: one namer, re-deriving from the
log every run. A second writer is not a helper, it is a race.

Two guards arrived with it. The Stop hook and the log's final append are
siblings rather than a sequence, so the exporter can read a log before the last
reply lands; a conversation ending in an unanswered user message is that race's
only fingerprint, and is retried a few times before surrendering loudly. And a
session opened but never spoken in produces no file at all, because the
warning-named husk files it used to produce kept being mistaken for typos and
"fixed" by hand.

### The churn treadmill (020)

The parser stamped a fresh `Generated on:` line into everything it wrote, so
re-exporting an unchanged conversation still produced a file differing by that
one line — after **every single assistant turn**. Measured in one project
before the fix: 116 of the first 145 transcript changes in git history were
that line and nothing else. Eighty per cent of the churn.

The lesson: **a stamp that records when a tool ran is not a fact about the
thing the tool made.** Comparison now steps over that line, and an unchanged
conversation is a genuine no-op. The mtime is still re-derived on that path,
because unlike the stamp it is a projection of the log and re-deriving repairs
a file some checkout scrambled.

### Pasted-back lines became quotes (026)

The developer replies to a single line of an answer by selecting it in the
terminal, pasting it at the top of the next prompt, and writing underneath.
Those lines were being credited to the user as their own words.

Recognising them is not a string comparison, and finding out why was the
interesting part. The clipboard receives what the terminal *drew*, not what was
typed, so emphasis and backticks are gone — comparing a reduced form of both
sides roughly doubled what was found. The pane's wrapping is baked in, so a row
is searched for *inside* the paragraph it came from. And a line long enough
that coincidence is implausible seeds a quote which then extends to neighbours
on a much weaker test, because a real paste ends in a short fragment.

A splitter bug surfaced underneath it: the obvious Lua spelling of "split on
newlines" yields a phantom empty line after every real one, which had been
doubling every blank line in every transcript since the beginning — 31,021
lines across 503 files. A blank line ends a blockquote, so it was also breaking
every multi-row paste into one quote per row.

### The record stopped lying about who was speaking (019, 021, 022, 023, 027, 028)

Six issues, shipped together, because they all touch the same few lines of the
same loop and fixing them apart would have meant fixing them twice.

**Answers to questions were being silently dropped (019).** They were recovered
by string-searching an English sentence for the question text followed by an
equals sign and a quote. Two assumptions had gone stale, both failing quietly:
an unquoted answer read as no answer, and the boundary was guessed from a comma
while 172 of the 503 answers in the corpus contain a comma of their own.

The fix was not a better parser for the sentence. **The harness had been filing
a structured copy all along**, on the message record rather than inside the
tool result, and nobody had looked. All 240 question exchanges carry it. It
also carries the free-text notes typed alongside a pick — 115 exchanges have
some, every one of which was being discarded, and they are usually the half
that says *why*.

The lesson is the one worth keeping: **when a parser is guessing, check whether
the thing it is guessing at was recorded properly somewhere else.**

**Escape codes were corrupting the files (021).** Slash-command output is
composed to be drawn, not stored. It had gone unnoticed for so long precisely
because transcripts are usually read in a terminal, where the bytes do exactly
what they were written to do and nothing looks wrong. Three encodings turned
up, all found by searching the corpus rather than reasoning about what ought to
be there.

**Machine-authored text was wearing the user's face (022).** A session log has
one seat for text addressed to the model, so the harness files its own messages
there too. All of it arrived under a numbered user-request heading and consumed
a number, so the numbering had stopped counting the conversation. Two kinds
present in the corpus were not in the issue's own table when work started —
background task notifications, in 64 logs and the largest offender by volume,
and skill invocations, whose whole reference text arrives behind them as though
it had been typed.

**Which model wrote a passage was recorded nowhere (023).** This one is worth
recording carefully, because the investigation reversed twice.

The issue's headline claim — that the `/model` command never records what was
chosen — was read as meaning the choice is unrecoverable. It is not: the output
line immediately after the command names it, in 32 logs. But the issue already
knew that, had documented it, and had rejected it for a reason that held up
when checked: 13 of 64 invocations are `Kept model as …`, a picker opened and
dismissed, so deriving a switch from the command would invent a change that
never happened in one case in five.

The source it chose instead is the model recorded on each assistant message.
Five models across roughly sixty-four thousand replies. One of them,
`claude-haiku-4-5`, wrote 791 replies and appears in no confirmation anywhere,
because nobody ever picked it — it is what subagents are delegated to. That
single row is the argument in miniature: **the picker records choices, the
per-message field records what actually ran, and where they disagree the second
one is telling the truth.**

The command is still rendered, at the developer's request, because what the
user *did* is a different fact from what the machine did. Both are kept.

**The two speakers now sit on opposite sides of the page (027, 028).** The
assistant's prose is padded to the right edge; the user's stays left. Running
commentary written while work was underway is marked with a quote marker and
the considered answer is left plain.

Two costs were accepted rather than worked around, and are recorded because a
later reader will otherwise think they were oversights. Four or more leading
spaces means *code block* in markdown, so a renderer shows right-padded prose
as a monospace box — these files are read in terminals, and that was judged the
right trade. And right-justifying a wrapped list item loses its hanging indent,
because a ragged-left edge and a fixed indent are two pictures and only one can
be on the page; the indent survives on the user's side, where nothing moves.

### Verification

Four test suites cover this: the export guards, the wrapping and alignment, the
question exchanges, and the harness traffic and model provenance. Beyond them,
the parser was run over every session log on the machine before the corpus was
rebuilt — 417 logs, no crashes, no surviving escape byte, no empty numbered
heading, and no envelope tag reaching the page except inside prose where
somebody had deliberately typed one in backticks.

Re-derive the corpus-wide counts with `rederive-transcripts`, which reports and
writes nothing unless told to.

## What is still open

- **Subagent transcripts are not being captured at all (025).** Claude Code
  moved sidechain logs into a `subagents/` directory one level down, and the
  exporter never descends. Nothing reported the change. This is why the Haiku
  row above has 791 replies and no transcript anywhere.
- **Whether a subagent's model deserves a beat of its own** cannot be settled
  until 025 ships.
- **Twelve transcript folders sit outside any repository**, holding 17
  transcripts nothing can preserve. Left deliberately; the developer will
  initialise them when it matters.
- **The naming of this file.** House convention calls for
  `phase-X-progress.md`, but the transcript issues are numbered plainly rather
  than by phase, and inventing a phase number for them would be inventing
  structure that does not exist. Named for the system instead. Worth a decision.
