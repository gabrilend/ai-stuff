# 1106 -- What the tool found

**Phase:** 11, the second view and the documentation
**Blocked by:** [1105](1105-the-site-is-built-by-a-tool.md)
**Blocks:** [1107](1107-the-phase-eleven-demo.md)
**Documents:** [the table of contents](../../docs/table-of-contents.md)

## Current behaviour

**Done.** The first run reported **165 dead links**. They fell into exactly two
classes and both were structural.

### Moving a file into `completed/` breaks every link in it

A hundred and sixty of them. An issue written in `issues/` links to
`../docs/004`; moved into `issues/completed/`, that now means `issues/docs/004`,
which is nothing.

The file still reads fine in an editor. Nothing complains. **The link dies at the
moment of success**, which is the least likely moment for anybody to check -- and
this project moves an issue into `completed/` several times a day while a phase
is being built.

That became [104-mend-links](../../src/104-mend-links.info.md), which repoints them
by basename. A tool rather than a careful afternoon, because an afternoon fixes
the ones that exist and this fixes the ones that will.

### A link to a document that was never written

One. An issue referred to `405-the-four-gates.md`, which was a planned issue that
became `406-commands-run-a-gauntlet.md`. The link had been dead since phase four
and nothing had ever looked at it.

The mender reports these and changes nothing, because they are either a typo or a
document somebody meant to write, and both need a person.

### And what the orphan report found

Fifty-three pages nothing in the prose pointed at. Most were companion files,
which the auto-linker then reached once it learned to treat a module's name in
backticks as a reference. The rest were real gaps, fixed at the source: the
roadmap now links each phase to what it turned out to teach, the table of
contents links to the document it is a table of contents for, and the generation
document links to the two descriptions that exist.

Four remain and they are all phase eleven's own files, which nothing outside this
phase has had a reason to mention yet.

### The lesson

**A tool that finds problems nobody fixes is a tool that trains people to ignore
it.** The report is run as part of the phase eleven demo, so it is read.

## Intended behaviour

The report is acted on, and this issue is where what it found is written down.

### Why this is an issue of its own rather than a step in the last one

Because the findings are the interesting part, and a step inside another issue is
a step nobody reads afterwards. Every dead link is a small piece of evidence about
how the documentation drifted, and the pattern across them is worth more than any
one of them.

A tool that finds problems nobody fixes is a tool that trains people to ignore it.

## Suggested implementation steps

1. Run it.
2. Fix every broken reference at its source -- in the Markdown, never in the
   generated HTML.
3. Record here what the classes of breakage were.
4. Run it again until it is clean, and say what "clean" turned out to mean.
