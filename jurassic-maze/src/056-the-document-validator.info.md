# 056-the-document-validator

Checks the documents and issues against each other, and against what is actually
on disk.

Read this page rather than the source.

## What it is for

A compiler for the written half. It cannot check prose — and prose is where
documentation actually rots — but it can check every claim that has a referent,
and each of those is a small thing nobody notices for months and which makes a
reader distrust the whole set when they finally do.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `check(root)` | project root | a list of complaints, and how many references were checked |

An empty list is the whole of a pass. `./validate-documentation` prints them and
exits non-zero if there are any.

## What it checks

| | |
| --- | --- |
| every relative link | resolved from the page's own directory, the way a reader's editor would |
| every source file | has a companion page, and every companion page has a source |
| every companion page | is not still the stub `new-source-file` wrote |
| every document | is listed in the table of contents |
| every issue the roadmap names | exists, in `issues/` or in `issues/completed/` |
| every issue | has its Current behavior, Intended behavior and Suggested implementation steps sections |
| every open question that claims to block an issue | names one that exists |
| the file index counter | is at least the highest index on disk, or two files will claim one number |

## The first thing it found

A hundred and nine broken links, all of one shape. Moving an issue into
`issues/completed/` silently invalidates every relative link inside it and every
relative link to it: `../docs/002-the-stone.md` becomes
`issues/docs/002-the-stone.md`, which is nowhere, and the roadmap's
`../issues/101-a-column.md` points at a gap.

Nothing warns. The links simply stop working and stay broken until somebody
clicks one. `057-the-relinker.lua` is the repair, and `./complete-issue` is the
move that does not cause it in the first place.
