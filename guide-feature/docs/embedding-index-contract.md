# The embedding index contract

What guide-feature's look tool (`docs/datapath-looking-into-the-project.md`)
needs to find in a project. The index is built by a per-project tool that
lives with the project-development tooling (perhaps delta-version, the owner
suggested). This page is the agreement between that builder and the look
tool, so either side can be rewritten without the other.

This is a first draft, written from the look tool's side. It changes when
the builder's guide is written.

## Where

`.embedding-index/` in the project root, beside `.git/`, and ignored by git.
It is made on each machine from that machine's clone, by a git hook
(`post-commit` where commits are made, `post-merge` and `post-checkout` where
they are pulled), so it always matches the checked-out commit.

## What

`.embedding-index/meta`, `name = value` lines:

| Field | Type | Meaning |
|---|---|---|
| `commit` | text | the commit the index was built from. The look tool refuses an index whose commit differs from the clone's, rather than reading stale pieces |
| `model` | text | the embedding model's name, as its endpoint reports it. Query vectors must come from the same model |
| `dimensions` | whole number | the vector length |
| `pieces` | whole number | how many pieces |
| `rule` | text | the name of the name-extraction rule, so queries are embedded the same way |

`.embedding-index/pieces`: one line per piece, tab-separated:

| Field | Type |
|---|---|
| piece number | whole number, from 1 |
| file | text, path relative to the project root |
| first line, last line | whole numbers |
| kind | text: `function`, `structure`, `block`, ... |
| names | text, the extracted names separated by spaces |

`.embedding-index/vectors`: piece by piece in the same order, `dimensions`
32-bit little-endian floats each, normalised to length 1, so a dot product is
the cosine. A flat binary file, because thousands of vectors read as text
would be slow to parse in Lua.

## The name-extraction rule

"find similar token labels, like variable names, class names, structs,
etc. It ignores syntax." The first rule, `names-v1`: identifiers (runs of
letters, digits and underscores starting with a letter or underscore), split
also at underscores and lower-to-upper case changes, lowercased, with
language keywords removed. Comments and strings are left out.
