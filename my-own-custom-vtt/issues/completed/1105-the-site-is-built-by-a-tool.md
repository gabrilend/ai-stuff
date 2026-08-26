# 1105 -- The site is built by a tool, and never by hand

**Phase:** 11, the second view and the documentation
**Blocked by:** [1104](1104-the-documentation-is-a-linked-site.md)
**Blocks:** [1106](1106-what-the-tool-found.md), [1107](1107-the-phase-eleven-demo.md)
**Documents:** [the shape of the code](../../docs/014-the-shape-of-the-code.md)

## Current behaviour

**Done.** `./build-docs` runs `103-build-documentation`, with the project root
hard-coded and overridable as the first argument.

Written in Lua because that is this project's preferred language, LuaJIT is
already a dependency for the rules layer, and this is string handling with no
determinism requirement and no place in the simulation. Writing it in C would be
choosing the language least suited to the job for no benefit.

Nothing in `docs/HTML/` is committed, for the same reason no other generated file
in this project is.

It reports unresolved references and orphans, and the report turned out to be
worth more than the site on the first run -- see
[1106](1106-what-the-tool-found.md).

## Intended behaviour

**Never create things manually. Always create the tool that creates them
automatically.** A hundred and twenty HTML pages written by hand would be a
hundred and twenty pages that stop matching their sources the first week.

Nothing in `docs/HTML/` is ever edited. It is regenerated.

### It is written in Lua

The preferred language of this project, LuaJIT syntax, and LuaJIT is already a
dependency because the rules layer needs it. A documentation tool in C would be
string handling in the language least suited to it, for a job with no
determinism requirement and no place in the simulation.

### It is not committed

Generated output is not in the repository, for the same reason no other generated
file is: a generated file in a repository is a file somebody eventually edits and
then wonders why the tool disagrees with it.

### It reports what it could not resolve

A link to an issue that does not exist, a mention of a source file with no
companion, a document nobody links to at all. **A dead link found by the tool is a
documentation bug found for free**, and a tool that silently emits dead links is a
tool that manufactures them.

An orphan -- a page nothing links to -- is worth reporting too. It is usually a
document that stopped being referenced when something was renamed.

## Suggested implementation steps

1. `build-docs` in the project root, with `${DIR}` hard-coded and overridable.
2. The tool walks the source directories, converts, resolves, and writes.
3. It prints what it made and what it could not resolve.
4. Run it, and fix what it finds.
