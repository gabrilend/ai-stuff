# measure-embedding-spread.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/measure-embedding-spread: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Reports how much of each embedding is shared with every other embedding, how
generic each colour anchor is, and which poems the current model has not
embedded at all.

General description (for a CEO): the machine that turns writing into numbers
has a habit -- almost everything it produces points the same direction,
regardless of what was written. This measures how strong that habit is, so
that the corrections built on top of it can be checked rather than trusted,
and so the figures quoted in the source comments can be refreshed instead of
going quietly stale after a model change.

It resolves the model the SAME way the build does, through the project's own
configuration. That is deliberate and is the main reason this exists as a
tool: the numbers first written into the source comments were measured by
reading an embeddings directory by name, and it was not the selected model's
directory. Reading the selection rather than typing a path removes that whole
class of mistake.

Usage:
  scripts/measure-embedding-spread                 # the selected model
  scripts/measure-embedding-spread /some/project   # a different project root
  scripts/measure-embedding-spread --model NAME    # force a model directory

What each section answers:
  [1] Is cosine similarity mostly measuring meaning, or mostly measuring the
      direction every vector already shares?
  [2] Do the colour anchors win by meaning, or by sitting near the average?
  [3] Does the stored (z-scored) colour verdict come out balanced?
  [4] Which poems does this model have no embedding for?

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `read_vectors(path, dims_out)`

```
Streams the embedding arrays out of a JSON file without building a Lua table
per number. A general JSON decode of a 100MB+ file spends its whole runtime on
bookkeeping this tool does not need; the numbers go straight into FFI doubles.
```

### `norm(v, d)`
(No comment above it in the source.)

### `cosine(a, b, d)`
(No comment above it in the source.)

### `mean_vector(list, d)`
(No comment above it in the source.)
