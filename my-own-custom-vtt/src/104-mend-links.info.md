# 104-mend-links

Repoints the relative links that moving a file broke.

## The breakage is structural and recurs forever

Every time an issue is finished it moves from `issues/` into `issues/completed/`,
and every relative link inside it silently becomes wrong: `../docs/004` now means
`issues/docs/004`, which is nothing.

The file still reads fine in an editor. Nothing complains. The link dies **at the
moment of success**, which is the least likely moment for anybody to check.

The first run of [103-build-documentation](103-build-documentation.info.md) found
a hundred and sixty-five of them, across eighty-five files.

## Why a tool and not a careful afternoon

An afternoon fixes the ones that exist. This fixes the ones that exist and the
ones that will, and this project moves an issue into `completed/` several times a
day while a phase is being built.

## How it mends

**By basename, not by guessing at paths.** A link's target names a file; if
exactly one file in the project has that name, the link means that one, and the
path is rewritten to reach it from wherever the link now lives.

If two files share a name it says so and changes nothing. An ambiguous mend is a
wrong mend half the time, and a wrong link that looks fixed is worse than a dead
one that looks dead.

It rewrites the **Markdown**. Never the generated HTML: fixing generated output is
fixing a symptom in a file that is about to be overwritten.

The RAM tiers, the generated site and the transcripts are excluded from the index.
Linking into any of them is linking at something that is regenerated, which is a
link that works until the next build.

## What it cannot mend

A link naming a file that does not exist anywhere. It reports those and leaves
them, because they are either a typo or a document somebody meant to write, and
both need a person.

The first run left exactly one: an issue referred to `405-the-four-gates.md`,
which was a planned issue that became `406-commands-run-a-gauntlet.md`. The link
had been dead since phase four.

## Running it

| Invocation | Does |
| --- | --- |
| `./mend-links` | reports and mends |
| `./mend-links --dry` | reports only |

## Related

- [103-build-documentation](103-build-documentation.info.md) — what found the problem
- issue [1106](../issues/completed/1106-what-the-tool-found.md)
