# 103-build-documentation

Turns the project's Markdown into a linked site in `docs/HTML/`.

## What it reads

| Section | From |
| --- | --- |
| the vision | `notes/` |
| the design | `docs/` |
| in progress | `issues/` |
| how it was built | `issues/completed/` |
| each piece | `src/*.info.md` |
| the source | every `.c`, `.h`, `.lua`, `.js` and `.html` in `src/`, highlighted |
| the edges | `input/`, `output/`, `desire/`, `faith/`, `strategems/` |
| the front doors | the scripts at the project root |

Two hundred and eighty-odd pages, each with the whole table of contents down its
left side, so every page is one click from every other.

## Where the crossing comes from

An explicit Markdown link is resolved against the source tree and rewritten to
the flat page name. Everything else is a **guess**, made only on text that
survived earlier passes — so never inside a code span that is not a module name,
and never inside a link:

| Written | Becomes |
| --- | --- |
| `issue 1101`, `issues 901` | a link to that issue |
| `open question 15.2` | a link to that question's anchor |
| `082-sprite` | a link to what that module is for |
| `083-test-sprite.c` | a link to the source itself |

A code span whose *whole content* is a module's name is treated as a reference
rather than as opaque, because that is how every document in this project writes
one. Treating them as opaque left a hundred mentions of `082-sprite` as dead
ends.

Companions and their code are cross-linked by the tool rather than by hand — a
companion links to its header, its source, its test and its program, found by
**name** rather than by index, because the index is the reading order and the name
is the subject.

## It reports what it could not resolve

A dead link found by the tool is a documentation bug found for free, and a tool
that silently emits dead links is a tool that manufactures them.

A dead link is also **marked on the page**, in red with a wavy underline. A link
that quietly becomes plain text is a link nobody ever fixes.

It reports orphans too — pages nothing in the prose links to. The contents list
still reaches them, so they are readable; but nothing points at them, which is how
a document stops being read.

The first run reported **165 dead links**. Nearly all of them were issues that had
moved into `completed/`, which silently invalidates every `../docs/` link inside
them. That became [104-mend-links](104-mend-links.info.md).

## Why Lua

This project's preferred language, LuaJIT is already a dependency because the
rules layer needs it, and this is string handling with no determinism requirement
and no place in the simulation. Writing it in C would be choosing the language
least suited to the job for no benefit.

## Nothing in the output is ever edited

It is regenerated, and it is not committed — a generated file in a repository is
a file somebody eventually edits and then wonders why the tool disagrees with it.

Syntax highlighting is inline. A page that reaches out to load a highlighter is a
page that breaks when the network does, and the whole point of the artifact is
that it is a directory you can open.

## Related

- [build-docs](../build-docs) — the script that runs it
- [104-mend-links](104-mend-links.info.md) — what its first report produced
- issues [1104](../issues/completed/1104-the-documentation-is-a-linked-site.md),
  [1105](../issues/completed/1105-the-site-is-built-by-a-tool.md),
  [1106](../issues/completed/1106-what-the-tool-found.md)
