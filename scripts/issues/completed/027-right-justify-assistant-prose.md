# Issue #027: Right-justify the assistant's prose

**Status: shipped.** Assistant prose is padded on the left so its right edge
lands at column 80; user prose is untouched. Structure whose meaning is its
column position is never moved. The markdown-renderer consequence described
below was accepted knowingly rather than worked around.

## Current Behavior

A transcript gives both speakers the same left margin. A user turn and an
assistant turn are distinguished only by their heading — `### User Request 7`
against `### Assistant Response 7` — so telling who is speaking means reading
a line of text that says so, rather than seeing it.

The renderer in `libs/conversation-parser.lua` wraps prose at 80 columns and
passes structure through untouched. Every wrapped line begins at column 0,
whoever said it.

## Intended Behavior

The assistant's prose sits against the right edge of the 80-column measure;
the user's prose stays against the left. The page itself then says who is
talking, and a reader skimming a long transcript can follow the turn-taking
without reading a word.

    ### User Request 7

    hiiiiiiiiiiiiiiiii can you read the vision file and tell me what you
    think?

    ### Assistant Response 7

                 I'll find the vision file under the project's notes
              directory and read it, then give you my take. Love2D 11.5
                and LuaJIT 2.1 are installed, and both project paths
                             point at the same directory.

Padding is added to the **left** of each line, never the right, so no line
gains trailing whitespace.

### What stays left

Right-justifying a paragraph is safe. Right-justifying anything whose meaning
depends on column position destroys it. The following keep their existing
treatment and are never padded:

- fenced code blocks, and every line inside one
- indented code blocks
- table rows, whose pipes must stay in a column to read as a table
- headings and the horizontal rules between turns
- a single token longer than the measure — a URL, an absolute path — which
  already refuses to wrap and would only be pushed off the edge

### The consequence, stated rather than worked around

In markdown, four or more leading spaces means *code block*. Right-padded
prose therefore renders as a monospace box on a web page rather than as
right-aligned text. This is a real cost and it was accepted knowingly: these
files are read in a terminal, an editor, `less`, and a diff, and in all four
the padding does exactly what it is meant to. The HTML documentation pages are
generated from the docs tree, not from transcripts, so nothing in that
pipeline is harmed.

If a rendered view is ever wanted, the fix is an alignment wrapper around each
prose block rather than a change to the padding, and both can coexist.

### Interaction with issue #028

Narration is marked with a leading quote marker. The marker sits at column 0
and the padding is measured from after it, so a quoted line's right edge lands
in the same place as an unquoted one:

    >           I'll find the vision file under the project's notes
    >        directory and read it, then give you my take.

                  The vision holds together. Three things stood out,
                    and one of them genuinely worries me.

## Suggested Implementation Steps

1. Give the wrapping routine a notion of which side a block is aligned to. It
   already distinguishes prose from structure in order to decide what may be
   wrapped at all; the same test decides what may be padded.
2. Pad after wrapping, never before. Wrapping measures the text; padding
   positions it. Doing them in the other order makes the measure wrong by the
   width of the padding.
3. Pass the speaker down from the two places that flush a block, so a user
   turn and an assistant turn render through the same routine with different
   alignment rather than through two routines that will drift apart.
4. Leave a line whose content already exceeds the measure exactly as it is —
   padding it to the right edge would push it past the edge, which is worse
   than an over-long line.
5. Test with a transcript containing all six structural kinds at once: a
   paragraph, a bullet list with a wrapped continuation, a fenced code block,
   a table, an indented block, and an over-long URL.

## Related Documents and Tools

- `libs/conversation-parser.lua` — the wrapping and formatting routines
- `README-backup-conversations.md` — its "Output Format" section describes the
  80-column behaviour and will need the alignment rule added
- Issue #028, which marks narration and shares the padding measure

## Notes

Requested directly by the developer while reviewing the Double Diaper Dungeon
transcripts, alongside #028. The two were asked for together and are most
easily read together.
