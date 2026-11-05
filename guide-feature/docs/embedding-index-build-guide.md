# Building a project's embedding index

How to give a project an embedding index that guide-feature's look tool
can read (`docs/embedding-index-contract.md`). The owner: "We'll have a
tool file that explains how to build that functionality, because we'll
build it once for each project." This is that file. It was written first,
then followed for guide-feature itself; what following it showed is at the
end, and the steps above were changed to match.

It lives in guide-feature for now, the only project that reads indexes, and
it is written so it can move unchanged to delta-version or the shared
scripts folder when the owner decides where it belongs (open question 2).
Nothing in it makes one project depend on another: a project that wants an
index copies the pieces it names into itself, the way `docs/vendored-code.md`
copies code.

## What you end up with

`.embedding-index/` in the project's own folder (beside `.git/` when the
project is a repository of its own; inside its folder when it lives in a
monorepo, as guide-feature does), ignored by git, holding three files:

- `meta`: which commit, which model, how many dimensions, how many pieces,
  which name rule;
- `pieces`: one line per piece: number, file, first line, last line, kind,
  names;
- `vectors`: one vector per piece, 32-bit little-endian floats, each of
  length 1.

The contract gives the exact format. It is rebuilt by git hooks after every
commit, pull and checkout, so it always matches the checked-out commit.

## 1. Copy the rules and the file format in

Copy guide-feature's `src/060-embedding-index.lua` into the project, beside
a `.upstream` note as `docs/vendored-code.md` says. It is one file with no
other dependency than LuaJIT's FFI. It holds:

- **`pieces-v1`**, how the code is cut into pieces (`M.pieces`, `M.cut`);
- **`names-v1`**, the names in a piece (`M.names`, `M.query_names`);
- **the file format**: `M.write`, `M.read`, and `M.check`, which says what
  the look tool would refuse.

A project in another language can write its own builder, as long as it
writes what the contract says; then this file is only the reference for
the two rules.

## 2. Decide which files are code

The builder reads the project's files as they are at the checked-out
commit, from git (`git ls-tree` and `git cat-file --batch`), never from the
working tree, so the index is exactly that commit's. It reads:

- files whose extension is in the `extensions` setting (Lua, shell, Python,
  C, JavaScript: `lua sh bash py c h js`);
- with `shebang = "on"`, files with no extension whose first line names an
  interpreter (`#!/bin/sh`), which is how most projects' `scripts/` are
  written;

and leaves out the folders in `skip`: code copied in from elsewhere
(`libs/`) describes another project's architecture, not this one's.
Documents are not indexed: the look tool shows code.

## 3. Cut each file into pieces (`pieces-v1`)

A piece is something a person would point at: a function, a structure, a
block.

1. **Folds first.** Each outermost `{{{ ... }}}` fold is one piece, from its
   opening line to its closing line. Projects in this repository fold every
   function and table this way, so the folds are already the pieces.
2. **With no folds**, a Lua function runs from a `function` (or `local
   function`, or `NAME = function`) line at the left edge to the `end` at
   the left edge; a shell function from `name() {` to `}`.
3. **Everything else** is cut into blocks at blank lines.
4. A piece longer than `piece-lines` (60) is cut into parts of that many
   lines.
5. **Kinds**: `function` when the fold's title or a line in it starts a
   function; `structure` when a line in it is a table (`NAME = {`); `block`
   otherwise.
6. A piece with no names in it (only comments, only `return M`) is left out.

## 4. Take the names (`names-v1`)

"find similar token labels, like variable names, class names, structs,
etc. It ignores syntax." For each piece:

1. Leave out comments and strings: Lua's `--` and `--[[ ]]`, `"..."`,
   `'...'` and `[[ ]]`; shell's and Python's `#` (but not `$#` or `${#x}`);
   C's and JavaScript's `//` and `/* */`; and a first `#!` line.
2. Take the identifiers: runs of letters, digits and `_` starting with a
   letter or `_`.
3. Split each at `_` and where a lower-case letter meets a capital
   (`canvasWidth`, `canvas_width` -> `canvas width`), and lower-case them.
4. Drop the languages' keywords (one list for every language, so a query,
   which has no language, is read the same way) and one-letter names.
5. Keep each name once, in the order first seen.

The piece's names, joined with spaces, are what is embedded. A query from
the look tool is read with the same rule, as code with no comments or
strings.

## 5. Embed them

Use the project's `embedder` endpoint (`docs/endpoints.md`): llama.cpp's
`llama-server --embeddings`, asked at `POST /v1/embeddings` in batches
(`batch`, 32 texts a request). Record the model's name as `GET /v1/models`
reports it: the look tool embeds its query with the same model, or refuses.
Make every vector length 1 before writing it.

Keep rebuilding cheap:

- **A commit that did not touch the project** (in a monorepo, most commits)
  changes nothing but the commit the index names. Record the project
  folder's tree (`git rev-parse HEAD:<folder>`) in `meta` as `tree`; when it
  is the same and the model is the same, rename the index to the new commit
  and embed nothing.
- **A piece whose names did not change keeps its vector**: look it up by its
  names in the index before, with the same model and rule.

Write the new index beside the old one (`.embedding-index.part/`), check it
(`M.check`), then swap it in, so a look never reads a half-written index.
Build one at a time per project: a lock folder (`.embedding-index.lock/`,
holding the builder's process id) that a later build takes over when its
process is gone.

## 6. Hook it to git

Add one marked block to the repository's `post-commit`, `post-merge` and
`post-checkout` hooks that runs the builder in the background:

    # >>> embedding index of /path/to/project (scripts/install-index-hooks)
    '/path/to/project/scripts/build-embedding-index' --hook post-commit "$@" </dev/null >/dev/null 2>&1 &
    # <<< embedding index of /path/to/project

- In the background, so git is never slowed, and never failing a git
  command: the builder logs instead.
- Beside what a hook already does: in a monorepo every project shares one
  set of hooks. A block goes before a hook's last `exit` line, where it
  would otherwise never run. Each project's block is marked with its own
  path, so installing twice changes nothing and removing takes out only it.
- `post-checkout` with its third argument `0` checked out files, not a
  commit: build nothing.
- When the commit moved while a build ran (two commits close together),
  build again.

## 7. Check it

The look tool refuses an index that is not right rather than reading stale
pieces. Before relying on one, check what it checks:

- `meta` has every field, of the right kind, and the rule is `names-v1`;
- the index's commit is the commit checked out;
- `pieces` has as many lines as `meta` says, numbered 1, 2, 3 in order;
- `vectors` is exactly pieces x dimensions x 4 bytes;
- every vector has length 1;
- every piece's file is in the project at that commit, and its last line is
  inside the file.

## guide-feature's own index

guide-feature follows this guide with:

- `src/060-embedding-index.lua`, the rules and the files (step 1);
- `src/061-build-embedding-index.lua`, `scripts/build-embedding-index`, the
  builder (steps 2 to 5), with its settings in `input/embedding-index`;
- `src/062-embedding-index-tools.lua`: `scripts/check-embedding-index`
  (step 7) and `scripts/install-index-hooks [--remove]` (step 6);
- `/.embedding-index*` in its `.gitignore`.

On kuvalu: `scripts/install-index-hooks` once, then every commit, pull and
checkout keeps the index built, with the embedder `endpoints` names. On each
voice, the turn builds the index of its clone after bringing it to the
canvas's commit (issue 503), with the embedder the canvas names.

Built against a stand-in embedding model here, guide-feature's index is
about 1,070 pieces from about 90 files: functions, structures and blocks
from `src/`, `scripts/` and the demos, in about a second.

### What following the guide showed

Following the first draft for guide-feature changed three things:

- **The index lives in the project's folder, not beside `.git/`.** The
  contract's first draft put it beside `.git/`; guide-feature is a folder
  of a monorepo, with no `.git/` of its own.
- **The `#!` line was read as names** (`usr bin env luajit`) in every Lua
  file and script; it is now left out like a comment.
- **A lock held by a builder that had ended, but whose process was not yet
  reaped, looked alive**, so every later build said another was running.
  A process is now alive only when it is there and not a zombie.

Two things were decided before following it, for a monorepo: the `tree`
shortcut, because most commits touch other projects, and marked hook
blocks beside what the shared hooks already do. `skip = "libs"` leaves out
82 pieces of copied code (the JSON library, the client, the RAM tiers
library) that describe other projects.
