# 303 — Types, by name and by width

## Current behavior

**After the C is compiled there is no type information left anywhere.**

A wire is two numbers. A port is a byte count. Nothing in the running
engine can tell a 32-bit integer from a 32-bit float, so nothing can
notice a wire that carries one into a slot expecting the other. The
values simply land, are read as the wrong thing, and produce answers
that are wrong in ways nobody can trace.

The catalogue from 302 is the last place that information still exists.

## Intended behavior

**A type is a name and a width, and the engine keeps both for three
different jobs.**

| job | needs the name | needs the width |
|---|---|---|
| refusing a wrong wire (307) | **yes** — the message is the deliverable | yes |
| sizing a port's cells (phase 2's 208) | no | **yes** |
| turning a static's text into bytes | **yes** | yes |

**Why the name and not only the width.** Four bytes versus four bytes
is not a message. *"reading → scale.0: box returns a 32-bit integer,
slot takes a 32-bit float"* is a five-second fix; "size mismatch" with
no mismatch in the sizes is an afternoon.

**A map file never mentions a type.** The catalogue knows the source
box's return type and the destination box's parameter type, both
derived from the C that actually runs, so the check needs nothing from
the file. A map that declared types would be a second source of truth
able to disagree with the first — and it would always be the one that
was wrong, because the compiler enforces the C and nothing enforces the
file.

**Two names for the same underlying type connect happily.** A count and
a duration that are both plain integers will wire together without
complaint. Telling them apart means wrapping each in its own struct,
which is the beginning of reimplementing a much larger type system, and
is deliberately not done. It belongs in a comment at the check, so the
next reader finds a decision rather than an oversight.

### Orderings

A comparator asks "is this value below, equal to, or above the
threshold?" — a question the engine cannot answer for a type it knows
only as bytes.

```
   value ──→ ┌─────────────┐ ──→ below
             │  comparator │ ──→ equal
   threshold │             │ ──→ above
   (a static port)         └─ asks the ordering for this type
```

So a value type that wants to be compared supplies an ordering — a
function beside it in the same source file, recognised by its name.
The catalogue records which types have one.

**A comparator whose type has no ordering is refused, and the refusal
lands at placement**, the moment the catalogue row is first consulted.
It cannot land at build time, because the generator never sees a map
and therefore never knows that anybody wanted to compare that type.

### Field tables

A static's value is written in a map file as text — `{ 5, 2.0, "hey" }`
— and becomes bytes in a port. Doing that needs the struct's field
list: names, types, and order.

The generator already reads struct definitions, so the field table
falls out of work it is doing anyway. Without it, every value type
would need its own hand-written reader, which is the thing this whole
phase exists to stop.

## Suggested implementation steps

1. Carry each type's name as text beside its width in the catalogue.
2. The wire check: compare both ends' type names, and produce the
   message above — both station names, the port, both type names.
3. Orderings: recognised by name suffix, recorded per type, refused at
   placement when a comparator's type lacks one.
4. Field tables emitted per struct, and one reader that walks a field
   table to turn text into bytes.
5. A test per refusal, each asserting the message word for word — the
   message is the product here, not a side effect.

## Open questions

- *Should the width check also run, given the names already matched?*
  Two types with the same name have the same width by construction, so
  it is redundant — but it is one comparison, and it catches a
  catalogue that was somehow built from stale sources. Cheap belt
  alongside the braces.
- *What happens to a static written for a struct whose fields later
  change?* The text no longer matches the field table, which is
  exactly the case the reader should refuse loudly rather than
  partially fill. Worth a test, because it is the shape of error a
  person hits while editing on the device.

## Blocked by

302.

## Blocks

306, 307, 308.

## Related

- [302 — The generator](302-the-generator.md), which emits all of this
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md),
  the check's home
- [308 — The kinds that pick an exit](308-the-kinds-that-pick-an-exit.md),
  where orderings get used
