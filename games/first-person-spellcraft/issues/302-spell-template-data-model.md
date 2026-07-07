# 302 — Spell template data model & registry

> Phase 3 · Spell System · foundational (defines *what a spell is*). Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 1. Depends
> on: [301](301-spell-path-and-level-taxonomy.md) (path & level vocabulary).

## Current Behavior

None of this exists yet. Paths and levels will be defined by issue 301, but there
is still no structure that says "a spell is a path, a level, an effect, and one-
or-more ways to cast it," and no table that holds the spell list. Nothing can be
cast because nothing has been defined to cast.

## Intended Behavior

A spell is a **template — never an instantiation.** This echoes the vision's core
discipline: the player "modify[s] templates. never instantiations" (notes/vision
~50). The spell list is a read-only table of molds; casting later stamps out
transient effects from a mold, but the mold itself is never mutated by a cast.

A **spell template** carries:
- a **magic path** (one, validated against issue 301's taxonomy),
- a **level** (one, within 301's bounds),
- a reference to the **effect** it produces (resolved later in issue 305a — here
  it is just a named/keyed reference, so the template stays pure data),
- a set of **casting methods** that can invoke it — *one or more*, honouring
  "there are more than one ways to do each of them" (~112-113). Stored as a list
  of method keys that must exist in the casting-method dispatch table (issue
  304a); the template asserts *which* routes are legal, not *how* they work.

A **spell registry / spell book** holds every template, keyed so a cast request
(issue 303) can name a spell and retrieve its mold. The registry is the thing the
count validator (301) tallies and the NCP chooser (Phase 5) will browse.

Templates are **loaded/validated on registration**: a spell naming an unknown
path, an out-of-range level, an unknown effect key, or an unknown casting method
is **refused with a clear error** — not silently defaulted. Fallbacks are treated
as warnings and warnings as errors (project discipline); a malformed spell is a
bug in the data, and we want it to shout.

## Suggested Implementation Steps

1. Define the spell-template structure as a plain data record (path, level,
   effect reference, list of casting-method keys, plus a stable id and display
   name for the book/UI).
2. Write the registry: an add/register path that validates each template against
   the 301 taxonomy and (once they exist) the 304a method table and 305a effect
   table, and refuses malformed templates loudly.
3. Provide read helpers by role: *look up a spell by id*, *list spells for a path
   and level*, *iterate the whole book* — the read paths the datapath names.
4. Seed the book with a small, honestly-Dominions starter set spanning a few
   paths and levels, each declaring more than one casting method, so downstream
   issues (303–307) have real data to flow. Keep the seed data separate from the
   registry machinery (data vs mechanism).
5. Extend the 301 count validator to report spells-per-path/level now that the
   registry exists.
6. Add a `.info.md` for the template/registry module.

## Data Structures / Functions / Files (by role)

- *Spell template* — the mold: id, name, path, level, effect reference, legal
  casting-method keys.
- *Spell registry (spell book)* — the keyed table of all templates + its
  validating add path and read helpers.
- *Starter spell data* — the initial Dominions-flavoured seed set, kept as data
  apart from the registry code.
- Files: a spell-template module and a registry module under `src/` (indexed per
  project convention), a separate seed-data file, and matching `.info.md`s.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 1.
- [301](301-spell-path-and-level-taxonomy.md) — supplies path/level validity.
- Blocks: 303 (cast requests name a template), 304 (methods listed by templates),
  305a (effect references resolved from templates).
