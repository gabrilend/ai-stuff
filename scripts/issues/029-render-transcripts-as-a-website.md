# Issue #029: Render a transcript corpus as a browsable website

## Current Behavior

A project's conversations live in its `llm-transcripts/` folder as wrapped
markdown, one file per conversation, named for the span of days it covers. That
is a good storage format and a poor reading format. To find where a decision
was made you open files one at a time and search each.

Issue 027 tried to improve the reading by changing the storage — padding the
assistant's prose to the right edge — and was withdrawn, because alignment is a
property of a view and the file is data. The alignment was not abandoned, only
relocated. This issue is where it was relocated to.

There is no renderer today. The pieces one would be built from all exist and
are proven, in `neocities-modernization`:

| piece | what it already does |
| --- | --- |
| `libs/markdown.lua` | markdown to HTML, dependency-free, escapes all text before emitting tags so content cannot inject markup, and emits no JavaScript |
| `src/page-head.lua` | the `<head>` every page needs, including a monospace font the site *ships* rather than hopes for — it exists because box-drawing layouts sheared apart on phones whose generic monospace lacks the glyphs |
| `src/page-template.lua` | strict `{MARKER}` substitution that fails the build on an unresolved marker instead of leaking it onto the page |

The font problem that `page-head` solves is the same problem a transcript page
has: an 80-column wrapped document full of rule lines needs a monospace face
that actually exists on the reader's device.

## Intended Behavior

A directory of transcripts becomes a directory of HTML pages plus an index, by
running one command. The generator reads only the `llm-transcripts/` folder and
writes only to an output directory; it never modifies a transcript.

What the pages do that the markdown cannot:

- **The two speakers sit on opposite sides.** `text-align: right` on the
  assistant's blocks — a stylesheet rule, changeable per reader, reversible,
  and costing the stored file nothing. This is issue 027's request, finally in
  a place where it works.
- **Narration reads as narration.** In the markdown it borrows the blockquote
  marker, which also means "a line the user pasted back". On a page those can
  be two different visual registers and the ambiguity disappears.
- **Model provenance is visible rather than stated.** The header names every
  model that served a reply and the body marks each change; a page can render
  that as a gutter down the side, so a reader *sees* where the character
  changes instead of reading a line saying so.
- **The corpus is one document.** An index listing every conversation by date
  with its first user request as a summary line, so the reading starts from a
  contents page rather than from a directory listing.

### The size guard

A transcript may contain code the model wrote out in prose. Measured across the
whole corpus (5,224 fenced blocks): the median block is 9 lines and three
quarters are under 20 — an illustration of a mechanic, which is exactly what
belongs in a development record. The top one per cent are 576 lines and more,
with the largest at 4,754. Those are whole files, not illustrations.

So a block longer than a threshold is replaced on the page by a marker naming
how many lines were withheld. The threshold is a setting, not a constant in the
prose: re-derive the distribution before choosing one rather than trusting the
numbers above, which will drift as the corpus grows.

This matters because of what the site is *for* — see issue 030. It does not
matter for the stored transcript, which is not published by this issue.

**One protection already exists and should be recorded so nobody rebuilds it:**
the parser drops every tool call and tool result, so file contents the model
*read* never enter a transcript at all. The only code that can appear is code
the model chose to show the reader, which is why the median block is nine lines.

### The landing page is a commit timeline, not a file listing

This is the part that decides the whole shape, so it comes before the mechanics.

**A directory of transcripts has no reading order.** The files are named for the
span of days they cover, which looks chronological and is not: several sessions
run at once, a conversation begun on Tuesday can be added to on Friday, and two
files can cover overlapping spans while belonging to entirely different threads
of work. Sorting by filename, or by date, or by modification time all produce an
order that no human ever experienced.

**The commits are the only true chronology.** A commit happened at a moment, in
a sequence, and the mirror rebuilds that sequence exactly — same message, same
dates, same order. Whatever else the site does, its spine should be that
sequence.

So the landing page is a timeline of commit messages, read top to bottom, with
the transcripts hung off it:

    ────────────────────────────────────────────────────
    Doors, then locks, then the two ends, then the keys
    Names read biggest first, and a window goes sooner
    The windows: a surface to put every later panel on

        ── the conversation these came out of ──────────
           sep 14 – 15   ·   claude-opus-5
           "can you read the vision file and tell me
            what you think?"

    ────────────────────────────────────────────────────
    Walls, gear, a pack, and the bar that decides what
    goes on
    Fifty words of hers, and a bar that moves in notches

        ── the conversation these came out of ──────────
           sep 15 – 16   ·   claude-opus-5, claude-fable-5-1

A reader with five minutes reads the commit messages alone and gets the story of
the project in the order it happened. A reader who wants to know *why* a
particular thing was done clicks into the conversation that produced it. Neither
reader has to know how the files are named.

### Why the empty commits matter

The mirror writes a commit even when a commit touched no transcript — an empty
one, carrying only the message. That looked like a curiosity and turns out to be
load-bearing here: without it, a stretch of work where several commits landed
between two user messages would appear on this page as a gap, and the story
would skip. With it, every message in the project's history has a place on the
timeline whether or not a conversation was recorded alongside it.

An empty commit costs a couple of hundred bytes and no file data at all, which
is a cheap price for a narrative that never jumps.

### What links to what

Each transcript page links back to the commits that sit against it, and each
commit on the landing page links into the conversation. The relationship is
many-to-many in both directions — one conversation usually produces several
commits, and a commit can follow a conversation that also produced others — so
the page has to express a grouping rather than a pairing.

The grouping is by *adjacency in the commit sequence*, not by matching dates. A
run of commits belongs to whichever conversation the transcript-touching commit
among them came from. Dates would seem to work and would quietly mis-file every
commit made during an overlapping session, which is the exact failure this whole
design exists to avoid.

## Suggested Implementation Steps

1. Decide where the generator lives. It is transcript tooling, so it belongs
   beside the exporter rather than inside any one project; the libraries it
   needs live in another project and should be reached rather than copied.
2. Read a transcript's structure rather than re-parsing its markdown. The
   headings are a fixed vocabulary — user request, assistant response, the
   marginal lines for commands and model changes — so splitting on them is
   reliable, and each block's *body* is what goes through the markdown
   renderer.
3. Render each conversation to one page, carrying its date span, its models and
   its first user request as the summary a reader sees before clicking in.
4. Build the landing page from the mirror's commit log rather than from the
   directory. Walk the commits oldest to newest; for each, take its message,
   and note whether it touched a transcript. That walk is the page.
5. Group a run of commits to the conversation the transcript-touching commit
   among them belongs to. Resist matching on dates, which looks equivalent
   and silently mis-files every commit made while two sessions overlapped.
6. Put every visual decision in one stylesheet. Alignment, the narration
   register, the provenance gutter. That is the whole point of the relocation
   and it should be obvious to the next reader.
7. Apply the size guard between parsing and rendering, so the threshold is one
   decision in one place.
8. Test with the shapes that break renderers: a project whose sessions overlap
   so the commit order and the filename order genuinely disagree, an empty
   commit run with no conversation beside it, and a transcript containing a table,
   a fenced block longer than the threshold, a pasted-back quote, a question
   exchange, and a model change mid-answer.

## Related Documents and Tools

- `libs/conversation-parser.lua` — writes the format this reads
- `README-backup-conversations.md` — the format's description, which is the
  specification for the parsing in step 2
- `issues/completed/027-right-justify-assistant-prose.md` — why alignment is
  here and not in the file
- `neocities-modernization/libs/markdown.info.md`,
  `neocities-modernization/src/page-head.info.md`,
  `neocities-modernization/src/page-template.info.md` — the three pieces to
  reach for
- Issue #030, which publishes what this generates
- Issue #003, which must be settled before anything generated here is published

## Notes

Raised after the developer read the padded transcripts on GitHub and asked for
hosting instead. The generator is the part that was always the right answer;
the padding was an attempt to get its benefit without building it.
