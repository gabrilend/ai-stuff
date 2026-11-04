# 035a — Three Parts That Never Meet

| | |
| --- | --- |
| Parent | 035 — share the transcript HTML renderer |
| Blocked by | nothing |
| Blocks | 035b, 035c, 035d |
| Status | complete, 2026-10-04 |

The transcript site becomes three parts in three folders — the table of
contents, the conversation page, and the films — joined only by the builder.
Asked for by the owner on 2026-10-04:

> I want to keep the table-of-contents system separate from the
> transcript-display system, ideally with gifs for each.

and, asked what "gifs for each" meant, she chose: the films are a third part
of their own.

## Current behavior

Built as intended below. Before, `scripts/transcript-site/` was one flat
folder: the reader, the page, the timeline, the palette, the builder and the
libraries side by side, with the timeline loading the palette and page-head
itself, and nothing to stop one job reaching into another.

Now the files sit in `conversation/` (`transcript-reader.lua`,
`conversation-page.lua`, `archived-exceptions.lua`,
`find-archived-exceptions`), `contents/` (`commit-history.lua`,
`attribution.lua`, `contents-page.lua` — the old timeline split three ways,
issue 035b) and `films/` (035d), each with its `.info.md`. The palette,
settings, builder and commands stay at the top. The test "loads no other
part" reads every Lua file in each part folder for a `dofile` naming a
sibling part, and all three pass. The transcript-care skill's HTML section
names the new places.

## Intended behavior

```
transcript-site/
  conversation/   the transcript display: reader, page, palette
  contents/       the table of contents: commit history, attribution, page
  films/          the films: model server, describer, matcher, two commands
  libs/           markdown, page-head, dkjson -- shared by all three
  fonts/          the shipped monospace
  build-site.lua  the only file that loads more than one part
  settings.lua    a project's settings, read and checked (035e)
```

**The parts never load each other.** Each takes plain tables in and hands
plain tables or strings out. A test reads every Lua file in each part folder
and fails if one names a file in a sibling part folder.

**The one thing two parts must agree on is a name, and it is written down
once.** The conversation page gives every commit line the id
`commit-<first seven hex digits>`; the table of contents links to
`<page>#commit-<first seven>`. The conversation page owns that rule (its
commit-anchor function, since it is the page that writes the ids); the
builder asks it for each recorded commit's anchor and hands the answers to
the table of contents with the rest of the evidence, so the table of
contents never loads the page and neither part knows the other's markup.

## Suggested implementation steps

1. `git mv` each file into its part folder; nothing changes inside them yet.
2. Fix every path that named the old place: `HERE ..` loads inside the
   files, `build-transcript-pages`, `build-pages-before-push`,
   `install-pages-hook`, the test file, the `.info.md` files, the
   transcript-care skill's HTML section. Grep the machine for
   `transcript-site/` afterwards.
3. Write the separation test into `tests/test-transcript-site.lua`.
4. Run the existing 40 checks; all pass unchanged.

## Related

- `035-share-the-transcript-html-renderer.md` (the parent)
- double-diaper-dungeon `issues/10-003a-the-renderer-comes-from-the-shared-library.md`
