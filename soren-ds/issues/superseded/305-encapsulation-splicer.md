# 305 — Encapsulation splicer

## Current behavior

The loader (303) parsed a box of `kind: "map"` as a single box
descriptor reference, but a `kind: "map"` box is actually a
*sub-map* — an entire graph of its own that needs to be flattened
into the parent's box list before the wire connector (304) can
hook anything to it. Without the splice, encapsulated sub-maps
are unfireable noise.

## Intended behavior

For each `kind: "map"` box the parse pass found, the splicer:

1. Recursively loads the sub-map referenced by the box's `ref`
   field. The sub-map's loader runs end-to-end, including its
   own encap splice pass for nested encaps.
2. Prefix-renames every box id inside the loaded sub-map by
   concatenating the parent's encap box id with a separator and
   the original id. This keeps id namespaces clean across
   splices.
3. Walks the sub-map's read boxes. Any read box marked with an
   `external` block becomes an *input port* on the encap box.
   The splicer rewrites every wire inside the sub-map that
   targeted the external read box's output to target whatever
   the parent's wire targeting the encap box's matching input
   port targets instead. The external read box is removed.
4. Walks the sub-map's write boxes. Any write box marked
   externally-consumed becomes an *output port* on the encap
   box. The splicer adds the write box's output to the parent's
   connection list as if the encap box itself produced it.
5. Inserts every remaining sub-map box into the parent's box
   list. The encap box itself disappears.

Encaps nest. After one pass, the parent may have new `kind:
"map"` boxes (from a sub-map whose load discovered its own
encaps). The splicer iterates passes until no `kind: "map"`
boxes remain. A maximum iteration count guards against
pathological cycles in the encap relation; hitting the cap is a
hard error.

## Suggested implementation steps

1. `splice_pass(map_t *)` — one pass of the algorithm.
2. `prefix_rename(sub_map, prefix)` — id rewriting helper.
3. `splice_external_reads(sub_map, parent, encap_box)`.
4. `splice_external_writes(sub_map, parent, encap_box)`.
5. `splice_until_flat(map_t *)` — iterate passes until done.

## Related documents

- `docs/012-soramech-runtime.md` — the encapsulated sub-maps
  section.
- `/home/ritz/programs/sora/soramech/docs/002-map-model.md` —
  parent project's encapsulation semantics.

## Blocked by

301, 303.

## Blocks

304 (connector wants a flat graph), 306, 311.
