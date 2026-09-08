# Issue #026: Show, in the transcript, which of the user's lines are quotes

## Current Behavior

A large share of what the user types is not the user's own words. It is a
line of the assistant's previous answer, selected in the terminal, copied,
and pasted back at the top of the next prompt so the reply can be aimed at
that one line rather than at the whole response. This is a habitual working
style, not an occasional thing.

The exporter has no idea this is happening. `parse_conversation` in
`libs/conversation-parser.lua` writes every user message through
`format_content`, which wraps it and nothing else. The pasted line and the
user's own reply to it land in the same undifferentiated block under the same
`### User Request N` heading, in the same typeface, with nothing separating
the borrowed sentence from the answer to it.

Read back later, the record says the user said all of it. The shape of the
exchange — *this specific claim, and my response to that claim* — is gone,
and it was the most informative thing about the turn.

### What a pasted line actually looks like

Three things happen to a line between the model writing it and it arriving
back in the prompt, and all three break naive matching.

**The terminal renders the markdown away.** This is the big one. The model
wrote:

```
**Notes poems still don't appear** on the 2,500 word pages I regenerated, ...
```

and what came back in the next prompt was:

```
  Notes poems still don't appear on the 2,500 word pages I regenerated, ...
```

The `**` markers are gone, because the user copied what the terminal *drew*,
not what the model *typed*. Emphasis markers, underscores and backticks all
vanish this way. Matching a pasted line against the raw JSONL text therefore
misses every line the model emphasised any part of.

**The terminal's own line-wrapping is baked in.** The pasted text carries the
row breaks of the pane it was displayed in, at whatever width that pane
happened to be, with a blank line between rows. One sentence of the model's
prose comes back as four lines, none of which is a line the model wrote.
Matching whole lines against whole lines therefore also fails; the pasted row
is a *fragment* that must be looked for inside the model's text.

**A left margin is added.** Claude Code draws assistant prose indented, and
that indent is copied along with the words. This is the "weird spacing" that
makes a paste recognisable at a glance.

### Measured, across every session log on disk

Produced by the survey scripts named under *Deprecation Watch* below; re-run
them for current numbers rather than trusting these.

| measure | value |
| --- | --- |
| user messages examined | 1416 |
| user messages containing at least one pasted-back line | 434 (about 31%) |
| user lines matched against the model's raw markdown | 1588 |
| user lines matched against the model's *rendered* form | 3028 |

Matching the rendered form rather than the source text nearly doubles what is
found. That single difference is the whole reason the naive version of this
feature would look broken.

### The left margin is a hint, not a rule

Of the lines carrying the two-space margin, a substantial minority match
nothing the model ever said. Inspected, they fall into four groups, and none
of them is a quote of the assistant:

- terminal output the user pasted from somewhere else (installer logs,
  progress lines with emoji, compiler messages)
- source code pasted out of a file
- the user's *own* long prose, wrapped by whatever they composed it in, which
  arrives indented for reasons that have nothing to do with the render
- assistant prose from a *different* session or a subagent sidechain, which is
  a real quote but has no source inside this conversation's log to match

So the margin cannot be the test. It corroborates; it does not decide.

### Short matches are almost all accidents

Bucketing every match by the length of the matched line shows a clean break.
Below about thirty characters the matches are things like `sure`, `great`,
`file.`, `way.`, `before touching it.` — ordinary phrases the user typed that
happen to also appear somewhere in a long earlier answer. Above about forty
characters, effectively every match is a genuine paste. Roughly 300 accidental
short matches sit below the break, against some 2700 real ones above it.

A single length threshold cannot have both, because genuine pastes end in
short fragments too: the tail of a wrapped paragraph is a line like
`file.` or `the years in between.`, which is real precisely because of what
sits above it.

### A second defect, found while building this

The line-splitter the wrapper uses is spelled `gmatch("[^\n]*")`, a pattern
that can match the empty string at the position just after a match. It
therefore yields a phantom empty line after every real one, and the wrapper
has emitted a blank line after every source line for as long as it has
existed. A single blank between two paragraphs arrives in the finished
transcript as two.

Measured on the tracked ai-stuff corpus immediately before the fix: 31,021
such lines across 503 transcripts.

An earlier draft of this issue claimed 67,540 lines across 1046 transcripts.
That was the same corpus counted twice: the sweep searched both
`/home/ritz/programming/ai-stuff` and `/mnt/mtwo/programming/ai-stuff`, which
are one directory reached through a symlink. Any future count of this corpus
should start from the real mount point, never from the home directory.

It is not merely untidy here. A blank line between two quoted lines *ends* a
markdown blockquote, so a pasted passage spanning several terminal rows would
have been broken into one quote block per row. The two defects had to be
fixed together for either to look right.

## Intended Behavior

Inside a `### User Request N` block, a line the user pasted back from earlier
in the same conversation is rendered as a markdown blockquote. The user's own
words are rendered exactly as they are today. A reader — or a program reading
the corpus later — can tell at a glance which sentence the turn was aimed at,
and read the response as a response.

The wrapper reproduces the blank lines it was given, neither adding nor
removing any.

Nothing else about the export changes: not naming, not identity, not which
messages are included, not the assistant blocks.

## Suggested Implementation Steps

1. **Split lines exactly.** Replace the pattern-based splitter with one that
   walks newlines directly, so that rejoining the result reproduces the input
   byte for byte. Everything below depends on blank lines meaning what they
   say.

2. **Compare rendered forms, not source text.** One reduction turns any text
   into what a reader would have seen: emphasis, underscore and backtick
   markers removed, every run of whitespace collapsed to a single space. Both
   sides of every comparison pass through it. Collapsing whitespace is what
   makes the terminal's arbitrary row breaks stop mattering, since the model's
   multi-line paragraph and the user's pasted fragment both become flat text.

3. **Keep a running record of what the model has already said.** Alongside the
   existing accumulator of assistant prose, retain the reduced form of every
   assistant text block seen so far in this conversation. The existing
   accumulator is emptied at each user turn; this one must not be, because the
   user quotes answers from far back. It must also be "so far" rather than
   "all of it": the model routinely echoes the user's phrasing back, and
   searching text the model had not yet written would mark the user's own
   words as a quote of a reply that did not exist yet.

4. **Search for the line inside that record, not against it.** A pasted row is
   a fragment of a longer paragraph. The test is whether the reduced user line
   occurs as a substring of any reduced assistant block, not whether it equals
   one.

5. **Seed on confidence, extend to neighbours.** Mark as a quote any line long
   enough that a coincidental match is implausible. Then walk outward from
   each marked line, taking adjoining lines on a far weaker test, and stopping
   at the first line that matches nothing. This is what recovers the short
   tail of a wrapped paragraph while leaving an isolated `sure` alone.

6. **Stop the walk at a blank line.** A paste arrives as adjacent rows, so a
   blank is where the paste ended and the user's own words began. A paste of
   two whole paragraphs is not lost to this: each paragraph seeds on its own,
   and the blank between them is rejoined by a later pass that marks any blank
   with quoted lines on both sides. That pass emits it as a bare marker, so
   the run stays one quote block rather than several.

7. **Keep the copied left margin rather than stripping it.** It carries
   information. Claude Code indents prose by two spaces, so quoted prose lands
   as a marker plus two — ordinary quoted text. Anything the user had indented
   further, a diagram or a code listing, lands as a marker plus four or more,
   which markdown reads as a code block inside the quote, and its alignment
   survives into HTML instead of collapsing. The wrapper must then leave that
   shape alone, the same way it already spares unquoted indented code.

8. **Let the existing wrapper do the wrapping.** It already understands
   blockquotes and repeats the marker on continuation lines, so the marking
   happens before the content formatter is called, not after.

9. **Test with fixtures.** `tests/test_conversation-parser-quoted-lines.lua`
   covers: a pasted row whose source the model had emphasised; a short tail row
   kept because the row above it is quoted; an isolated short coincidence left
   alone; a run that stops rather than swallowing the reply beneath it; a paste
   of two paragraphs staying one quote; and an authored blank line staying
   exactly one blank line.

10. **Leave the corpus decision to #024.** Existing transcripts keep their
    current shape until each project's next export rewrites them.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the file changed. The per-conversation
  state, the content formatter and the wrapper all live here.
- `backup-conversations` — the Stop-hook exporter driving the parser. Not
  changed by this issue.
- `README-backup-conversations.md` — documents the wrapping rules, including
  the blockquote handling this issue relies on.
- `tests/test_conversation-parser-quoted-lines.lua` — the fixtures for both
  defects.
- `issues/021-strip-terminal-escape-codes-from-transcripts.md` — the other
  place where text composed for a terminal has to be reinterpreted as text
  for a file. Same underlying confusion, opposite direction.
- `issues/024-backfill-existing-transcript-corpus.md` — the blank-line fix
  means every transcript is rewritten on its project's next export, which is
  a partial answer to the question that issue asks.
- `issues/025-capture-subagent-session-logs.md` — while sidechains go
  unexported, a line quoted from a subagent's output has no findable source,
  which is one of the four unmatched groups above.

## Deprecation Watch

Four survey scripts produced the measurements in this file: match rates, the
margin histogram, the rendered-form comparison, and the match-length buckets.
**Decided: none are kept.** They were scaffolding for a question that has been
answered, they never entered the repository, and re-deriving any number here
means writing the few dozen lines again against a corpus that will have moved
on anyway. Nothing to remove and nothing to maintain.

## Metadata

- **Priority**: done.
- **Complexity**: Moderate. The reduction and the substring search are simple.
  The judgement is entirely in the seed-and-extend rule and its two
  thresholds, which are the only part that can be wrong in a way a reader
  would notice.
- **Dependencies**: None hard. #025 would enlarge what can be matched.
- **Impact**: About a third of user turns gain structure they did not
  previously have. No text is added, removed, or altered — only marked. The
  blank-line fix removes roughly 5% of the corpus's lines, all of them blank.

## Success Criteria

- A pasted line whose source the model emphasised is still recognised.
- A paste spanning several terminal rows is marked across all its rows.
- A short generic phrase with no quoted line near it is left alone.
- A quote run does not cross a blank line into the user's own reply.
- The visible characters of every user message survive unchanged; the only
  difference is the quote marker and the re-wrapping it implies.
- One authored blank line remains one blank line.

## Open Questions

All resolved.

1. **What should a quoted line look like in the file?** *A plain markdown
   blockquote.* The alternative considered was marking the quote and naming
   which answer it came from; rejected as more machinery than the record needs.
2. **Should a run of pasted rows be re-joined into one paragraph?** *No — the
   rows are kept exactly as they arrived.* Joining would read better as prose,
   but a pasted diagram comes back through the same path and its line breaks
   are its entire content.
3. **Does the search look at the user's own earlier messages too?** *No, only
   the assistant's answers.* People do quote themselves, but a user repeating
   their own phrasing is not necessarily quoting, and the extra reach is not
   worth the extra false marks.
4. **Should the left margin alone ever be enough?** *No, a content match is
   required.* The margin also lands on pasted installer output, pasted code,
   and the user's own indented prose.
5. **What are the two thresholds?** *Forty characters to seed, twelve to
   extend.* Measured across the corpus, the setting barely matters: sweeping
   from 30/8 to 60/20 moves the number of messages carrying a quote only from
   435 to 427. They are single named constants, easy to change if living with
   the result suggests otherwise.
6. **Should a quote from much earlier be treated differently from one quoting
   the immediately preceding answer?** *No.* A callback and a reply are marked
   the same way; distinguishing them would need the export to carry a notion of
   distance it does not currently have, for a difference a reader can already
   see from the surrounding text.
7. **Should the blank-line defect have been fixed here or deferred?** *Fixed
   here.* It had to be: a blank line between two quoted lines ends a
   blockquote, so leaving it would have broken every multi-row quote into
   separate blocks. The cost is that every transcript in every project is
   rewritten on its next export.
