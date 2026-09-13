# 101 — The project is built by its tools

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | — |
| Blocks | 102, 104, 107, 113, 608 |
| Reads | [the shape of the code](../../docs/013-the-shape-of-the-code.md) |
| Open questions | none |

## Current behavior

Built. The project is a directory the monorepo's rules describe, and every file
in it that is not prose was made by a tool that lives beside it:

- `./new-source-file`, `./new-document`, and `./new-issue` claim indices from
  `.file-index-counter`, stamp the licence, write companion stubs, and add
  tracker rows. Each accepts a list, so a whole phase of files is one command.
  `./fill-source-file` rewrites a body without disturbing the notice, and
  `./complete-issue` moves a finished issue into `completed/`, rewriting its
  links and marking the tracker.
- `./compile` parses every Lua file the project owns with LuaJIT and packages
  the computer build into the RAM tier when a doorway file exists; it knows the
  shape of the handheld build and refuses it by name until phase 8 supplies the
  pieces.
- `./dependencies-version-updater` reads the manifest in `input/dependencies`,
  rewrites its pins and versions to what is current, installs pinned files from
  sibling projects' git history into `libs/`, and compiles. `./update-dependencies`
  and `./install-dependencies` are symlinks to it that do one job each, chosen
  by the name it was invoked as through a dispatch table.
- `./validate-documentation` is the compiler for the written half: broken links,
  malformed issues, roadmap drift, stale open questions, documents missing from
  the table of contents, source files without companions, and coverage claims
  naming issues that do not exist.
- `./build-documentation` turns every document, issue, companion and test into
  cross-linked pages with a filterable rail, issue numbers as links, and
  interactive pieces — through the generator in `scripts/`.
- `./run-tests` runs the validator and every numbered program under `tests/`,
  and `./run-phase-demo` offers the phase demos once they exist.

The two RAM tiers exist as symlinks, the standing-note directories hold their
first entries, and `notes/vision` holds the author's words.

## Intended behavior

**Nobody creates a file by hand.** The monorepo's rule is that things are made
by tools that make things, and a project's first deliverable is therefore the
set of tools that make its files, before any file that matters exists. The
reasons are the ones the shape-of-the-code document gives: an index claimed by
hand is an index two files will share; a licence header copied by hand is one
that rots; an issue written without its frame is one the validator refuses a
month later.

Three properties the tools hold:

- **One root, overridable.** Every script hard-codes the project root at its
  top and takes another as a leading argument, so it runs from anywhere and
  against a checkout anywhere.
- **Errors over fallbacks.** A tool that cannot do its job says so and stops. A
  collision with the counter, a missing progress file, a dependency whose
  version drifted from the manifest, a dead link in a document — each is
  refused by name, never patched over.
- **Read `input/` first, write `output/goodbye` last.** The programs that do
  work follow the project's own convention from the first commit.

The compile script and the dependency updater exist **before any source**, on
purpose: a compile step fitted around finished code inherits whatever the code
became, while one written first is a statement about what the code is going to
be. `./compile --target handheld` today lists exactly what phase 8 must supply.

## Suggested implementation steps

1. Make the directories the monorepo's rules name, the two RAM-tier symlinks,
   the counter at zero, the ignore file, and the licence files.
2. Write `new-source-file` with the licence block in Lua's comment syntax as its
   single copy; give it `--into`, `--summary`, `--peek`, and `--from-list`.
3. Write `new-document` and `new-issue` on the same pattern; `new-issue` derives
   the *Blocks* column as the inverse of every line's *Blocked by* over the whole
   list before writing anything, so the two cannot disagree.
4. Write `compile`: a parse pass over every Lua file, a dispatch table of build
   targets, a scratch-then-move archive for the computer, and a refusal for the
   handheld that names the engine, the toolchain, and the maps directory.
5. Write the dependency manifest as stanzas of `key: value` lines with a `kind`
   per stanza, and the updater as one script with a dispatch table keyed by the
   name it was invoked as. Fresh values come from one function per kind.
6. Write `validate-documentation` in LuaJIT: the seven checks, every listing
   read-only, sorted output so two runs diff cleanly.
7. Write the HTML generator in `scripts/`, numbered, with its companion: a
   deliberately incomplete Markdown, a cross-reference pass that fails on a dead
   link, the contents rail, the badges, and the toys keyed by name.
8. Write `run-tests` to discover `tests/*.lua` rather than list them, and
   `run-phase-demo` to discover demos the same way.

## Related documents and tools

- [The shape of the code](../../docs/013-the-shape-of-the-code.md)
- [The tests come first](../../docs/014-the-tests-come-first.md)
- `../input/dependencies` — the manifest the updater reads
- `../scripts/017-the-documentation-becomes-html.info.md` — the generator

## Still open

Nothing beyond the questions in the table. The one thing this issue does not
do is run inside the monorepo's sandbox tool; that is a choice about where work
happens, not about what the project is.
