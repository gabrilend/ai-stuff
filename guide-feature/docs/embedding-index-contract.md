# The embedding index contract

What guide-feature's look tool (`docs/datapath-looking-into-the-project.md`)
needs to find in a project. The index is built by a per-project tool that
lives with the project-development tooling (perhaps delta-version, the owner
suggested). This page is the agreement between that builder and the look
tool, so either side can be rewritten without the other.

Agreed (2026-11-05, issue 502): written first from the look tool's side,
then settled by writing the builder's guide
(`docs/embedding-index-build-guide.md`) and following it for guide-feature.
`src/060-embedding-index.lua` reads, writes and checks exactly this.

## Where

`.embedding-index/` in the project's own folder, and ignored by git: beside
`.git/` when the project is a repository of its own, inside its folder when
it lives in a monorepo (guide-feature is `ai-stuff/guide-feature/`).
It is made on each machine from that machine's clone, by a git hook
(`post-commit` where commits are made, `post-merge` and `post-checkout` where
they are pulled), so it always matches the checked-out commit.

## What

`.embedding-index/meta`, `name = value` lines (text in double quotes, whole
numbers bare, `#` comment lines), written last, so an index with a meta is
whole:

| Field | Type | Meaning |
|---|---|---|
| `commit` | text | the full commit (40 hex digits) the index was built from. The look tool refuses an index whose commit differs from the clone's, rather than reading stale pieces |
| `model` | text | the embedding model's name, as its endpoint reports it. Query vectors must come from the same model |
| `dimensions` | whole number | the vector length |
| `pieces` | whole number | how many pieces |
| `rule` | text | the name of the name-extraction rule, so queries are embedded the same way (`names-v1`) |
| `tree` | text, optional | the project folder's git tree at that commit, so a builder can tell a commit that did not touch the project; the look tool does not read it |

`.embedding-index/pieces`: one line per piece, tab-separated:

| Field | Type |
|---|---|
| piece number | whole number, from 1 |
| file | text, path relative to the project's folder, with no tab or newline |
| first line, last line | whole numbers |
| kind | text: `function`, `structure` or `block` (`pieces-v1`) |
| names | text, the extracted names separated by spaces |

`.embedding-index/vectors`: piece by piece in the same order, `dimensions`
32-bit little-endian floats each, normalised to length 1, so a dot product is
the cosine. A flat binary file, because thousands of vectors read as text
would be slow to parse in Lua. Its size is exactly pieces x dimensions x 4
bytes.

## The name-extraction rule

"find similar token labels, like variable names, class names, structs,
etc. It ignores syntax." The first rule, `names-v1`: identifiers (runs of
letters, digits and underscores starting with a letter or underscore), split
also at underscores and lower-to-upper case changes, lowercased, with
language keywords (one list for every language) and one-letter names
removed, each kept once in the order first seen. Comments, strings and a
first `#!` line are left out. A query is read by the same rule, as code
with no comments or strings. The pieces' names, joined by spaces, are the
text embedded.

## How pieces are cut

`pieces-v1`, the builder's business and not the look tool's, is in the
build guide: each outermost `{{{ }}}` fold, else functions at the left edge,
else blocks between blank lines, at most `piece-lines` lines each.

## What makes an index usable

The look tool, and `scripts/check-embedding-index`, refuse an index when:
`meta` lacks a field or has one of the wrong kind; its rule is not
`names-v1`; its commit is not the checkout's; `pieces` and `meta` disagree
on the count, or the pieces are not numbered 1, 2, 3 in order; `vectors` is
not pieces x dimensions x 4 bytes; a vector is not of length 1; a piece's
file is not in the project at that commit, or the piece ends past its last
line.
