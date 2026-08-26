# 801 — One outward surface, six times

Produces `src/056-port-field.md`.

## Current behavior

Nothing. "All six faces are the same part; what differs is which connector is
populated" is asserted in three documents and specified in none.

## Intended behavior

**The identical outward interface every face carries**, and the population options
that turn one of them into a storage line, an output tube or a host link.

### Why this is worth a blueprint of its own

`008` entry 4 records the conflict in the original page: it wants six storage
lines *and* one face spent on an output tube, which is seven faces' worth of
purpose on six faces. The resolution is that a face's outward surface is not
committed in silicon. It is a **field of pads with a defined electrical
character**, and what gets soldered to it is an assembly decision.

The consequence is the thing that makes this machine affordable: **one face
assembly design, built six times.** Two designs would mean two mask sets, two
qualifications, two yield curves and two spares inventories, for a part that costs
what a face costs.

### What the field has to carry

Every population needs some of these and none needs all:

| group | what for | rough count |
|---|---|---|
| power | 48 V in, and return | tens of pads, high current |
| high-speed differential | a storage line, or a cabled spout | thousands of pairs |
| fine-pitch parallel | a bonded or byte-mode spout | millions |
| low-speed control | management, telemetry, the interlock | tens |
| ground and shielding | between everything above | the majority |

The **fine-pitch parallel group is the hard requirement**, because `902` wants ten
micron pitch over the whole field and nothing else does. A field built for
microbumps cannot later carry a bonded spout, and a field built for hybrid bonding
is expensive on five faces that will never use it.

**This is the central trade of the ticket** and the blueprint must resolve it
rather than describe it. The likely answer is a **zoned field**: a fine-pitch
region covering most of the area, plus a coarse region at the perimeter for power
and differential pairs — so a storage face populates only the perimeter and leaves
the middle unbonded, and a spout face populates everything.

### The populations

- **Storage line.** Perimeter zone only. Power, and the differential pairs `802`
  needs.
- **Host link.** Perimeter zone, fewer pairs.
- **Cabled spout.** Perimeter zone, all pairs (`067`).
- **Byte-mode spout.** Fine zone at thirty-two micron pitch, plus perimeter for
  power (`068`).
- **Bonded spout.** Fine zone at ten micron pitch (`066`).
- **Blank.** Power only. A valid population, and cheaper.

### What crosses the cold plate

Everything on this field has to reach the interposer through `202`'s sixteen via
islands. **The islands were sized for the perimeter zone's conductor count and
cannot carry the fine zone's**, which is why a bonded spout's conductors do not go
to the interposer at all — they go to the cage, through the face, which is a
completely different route. The blueprint must draw both routes and say which
population uses which, because getting this wrong is discovered at assembly.

## Symbols this must publish

Field dimensions and zones. Pitch and pad count per zone. Current capability per
power pad. Differential pair count. Population table with the pads each uses.
Routing path per zone. Impedance and loss for the differential group.

## Constraints this must assert

- Every population's pad requirement fits its zone.
- Power pads times per-pad current exceeds `401`'s per-face input with margin.
- Perimeter zone conductor count is under what `202`'s via islands carry.
- Fine zone pad count at ten micron pitch is at least `902`'s requirement.
- All six faces have identical fields. Asserted, so a later optimisation that
  thins five of them has to argue for itself.

## Suggested implementation steps

1. Enumerate the populations and what each needs, before designing the field.
2. Resolve the zoning trade and price the fine zone that five faces will not use.
3. Draw both routing paths and map populations to them.
4. Check every population against the zone it uses.

## Blocks

`802`, `901`, `902`, `906`, `907`, `1202`.

## Blocked by

`202`, `401`, `902`.

## Related documents

`008` entry 4. `000` for the six-identical-faces claim.
