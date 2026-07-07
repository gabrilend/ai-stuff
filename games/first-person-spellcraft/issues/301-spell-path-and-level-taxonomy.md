# 301 — Spell path & level taxonomy (the Dominions vocabulary)

> Phase 3 · Spell System · foundational (the vocabulary every later spell issue
> speaks). Datapath: [datapath-spell-system.md](../docs/datapath-spell-system.md)
> Stage 1.

## Current Behavior

None of this exists yet. There is no notion of a magic path, a spell level, or
which paths and levels are legal. The vision asks that "the spell list be
dominions spells" (notes/vision ~90) and speaks of "spells of each level in each
path" (~111), but nothing has yet written down what the paths and levels *are*.

## Intended Behavior

There is a single authoritative place that defines the **magic paths** and the
**spell levels** the whole spell system draws from — the shared vocabulary that
spell templates, casting methods, the NCP chooser, and the eventual UI all
reference. Concretely:

- A fixed set of **magic paths** modelled on Dominions' sorcery/elemental paths:
  Fire, Air, Water, Earth, Astral, Death, Nature, Blood — "~8 paths". Each path
  is data: a stable key, a display name, and room for later per-path traits
  (opposed path, colour for rendering, gem type for the Phase 7 economy).
- A fixed **level range** modelled on Dominions' spell levels (roughly 1 through
  9). A level is a small integer with a defined minimum and maximum.
- Every path/level pair is a valid *coordinate* in the spell space; a spell
  template (issue 302) names exactly one path and one level.
- The **exact counts are never hardcoded in prose.** A **count validator /
  statistics utility** reports how many paths, how many levels, and (once the
  spell registry exists) how many spells occupy each path/level cell. Docs and
  other code reference the validator's output rather than restating it, so the
  numbers cannot go stale.

Because behaviour will branch on path and on level in many places (rendering
colour, gem cost, opposed-path rules), paths and levels are stored as
**dispatch-table-friendly data keyed by their stable key**, not as scattered
constants — so a new per-path rule is a new column of data, not a new switch.

## Suggested Implementation Steps

1. Write the taxonomy module: a table of path records keyed by path key, and the
   level bounds. Give each path a stable key, a display name, and placeholder
   slots for the later per-path traits so adding one is a data edit.
2. Provide read helpers by role: *is this a valid path?*, *is this a valid
   level?*, *list all paths*, *list all levels*, *iterate path/level cells*.
3. Write the **count validator / statistics utility** as a standalone runnable
   script (hard-coded `${DIR}` at top, overridable by argument, all paths
   relative to `${DIR}` — the project script convention). On run it reports the
   path count, the level range, and — guarded so it works before the registry
   exists — the spell-per-cell tally once issue 302 lands.
4. Add a `.info.md` companion listing the taxonomy module's external helpers and
   their inputs/outputs, so readers consult it before the source.
5. Leave comments recording *why* the path set and level range were chosen (they
   mirror Dominions) so a future editor changing them understands the lineage.

## Data Structures / Functions / Files (by role)

- *Path record* — key, display name, slots for opposed-path / colour / gem type.
- *Taxonomy table* — all path records, plus the level minimum and maximum.
- *Validity checks* — path validity, level validity (used by 302's template
  loader to refuse malformed spells rather than fall back).
- *Count validator script* — the anti-staleness tool the docs point at.
- Files: a low-index taxonomy source module under `src/`, its `.info.md`, and a
  validator script (its home to be decided with the other Phase 3 tools).

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 1.
- [vision-overview.md](../docs/vision-overview.md#a-note-on-counts-and-statistics)
  — the counts-and-statistics discipline this validator satisfies.
- Blocks: 302 (templates name a path & level), and every issue downstream.
