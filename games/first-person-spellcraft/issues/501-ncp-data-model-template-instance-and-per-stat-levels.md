# 501 — NCP Data Model: template, instance, and per-stat levels

> Phase 5 taproot. Everything else in the phase rests on the shape defined here:
> the mold an NCP is stamped from, the living copy that adventures, and the
> per-stat level block the Dungeon Master will one day read to fit a puzzle to a
> mind. Read this first; the rest of Phase 5 assumes it.
>
> Terminology: **NCP = New Character Person** (vision ~113). The vision also says
> "NPC" loosely for the same creature; we standardize on NCP. See
> [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. There is no notion of a character, no stats, no
inventory, no memory — the engine (Phase 1) can move a body through rooms, but
nothing describes *who* that body is or *how capable* it is.

## Intended Behavior

There are two clearly separated kinds of thing, and the separation is the whole
point:

- An **NCP template** is a *mold*: base per-stat levels, a starting-inventory
  manifest, and a reference to a seed persona (the common pattern, defined in
  issue 504). Templates are **configured, never played** — this is the
  "configure templates, never instantiations" strategem. Editing a template must
  never reach into an already-living instance.
- An **NCP instance** is a *stamped copy* that actually adventures: it owns its
  own per-stat level block, a live inventory (starting manifest expanded into
  real carried goods), a handle to its own memory store (issue 502), a handle to
  its active companion persona (issue 504), and a body/pose the engine can place
  in a room and the player can later seize (issue 508).

The **per-stat level block** holds one level *per stat*, each advanced
independently — deliberately NOT a single "character level." Phase 6's Dungeon
Master reads these exact per-stat numbers to tune a puzzle to the stat that will
carry the attempt, so every stat must be individually addressable and readable.
Parties with differing per-stat levels are a vision idea explicitly deferred
("save parties for the sequel") — build a **single adventurer** now, but design
the stat block so per-stat tuning already works, so the sequel needs no reshape.

Stamping a template mints an instance whose values are *copies*, not shared
references — so the mold and the copy can never entangle.

## Suggested Implementation Steps

1. Define the **per-stat level block** structure first: a small, fixed set of
   named stats, each an independently-advanceable level. Do not hardcode the stat
   list count in docs — expose it so a validator can report it. Provide a
   read-one-stat and advance-one-stat operation; the DM will call the reader.
2. Define the **starting-inventory manifest** shape (what a template promises a
   newborn carries) and the **live inventory** shape (what an instance actually
   holds, growing with loot). Keep the manifest → live-inventory expansion a
   single explicit step so the mold/copy boundary is obvious. The live inventory
   must be able to hold gold, gems, resource notes, and trial logs, since Phase 7
   reads exactly those on return.
3. Define the **NCP template**: base stat block + starting manifest + seed-persona
   reference. Templates are data, editable through a future UI (Phase 7), never
   through gameplay.
4. Define the **NCP instance**: stamped stat block, live inventory, memory-store
   handle, persona handle, and body/pose handle for the engine.
5. Write the **stamp operation** that turns a template into an instance: deep-copy
   the stat block, expand the manifest into a live inventory, attach a fresh
   memory store, clone the seed persona. Guarantee no shared mutable state leaks
   from mold to copy (a test that mutates the instance and asserts the template is
   untouched — and vice versa).
6. Provide a corresponding `.info.md` for each source file listing the external
   functions and their inputs/outputs, treating the structures as black boxes.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — the flow this
  data model feeds; see "Structures, by role."
- [strategems](../strategems/README) — "configure templates, never instantiations."
- Blocks / is-blocked-by: memory store (502) attaches here; persona (504)
  references the seed; the weak solver (506) and DM (Phase 6) read the stat block.
