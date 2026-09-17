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

## Suggested Implementation Steps

1. Decide where the generator lives. It is transcript tooling, so it belongs
   beside the exporter rather than inside any one project; the libraries it
   needs live in another project and should be reached rather than copied.
2. Read a transcript's structure rather than re-parsing its markdown. The
   headings are a fixed vocabulary — user request, assistant response, the
   marginal lines for commands and model changes — so splitting on them is
   reliable, and each block's *body* is what goes through the markdown
   renderer.
3. Render each conversation to one page, and build an index from the headers:
   each file's date span, its models, and its first user request.
4. Put every visual decision in one stylesheet. Alignment, the narration
   register, the provenance gutter. That is the whole point of the relocation
   and it should be obvious to the next reader.
5. Apply the size guard between parsing and rendering, so the threshold is one
   decision in one place.
6. Test with the shapes that break renderers: a transcript containing a table,
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
