# 303 — Types compared by width

## Current behavior

**After the C is compiled there is no type information left anywhere.**

A wire is two numbers. A port is a byte count. Nothing in the running
engine can tell a 32-bit integer from a 32-bit float, so nothing can
notice a wire carrying one into a slot expecting the other. The values
land, are read as the wrong thing, and produce answers nobody can trace.

The catalogue from 302 is the last place that information still exists.

## Intended behavior

**Two types are compatible when they are the same number of bytes, and
nothing else is consulted.**

The size is already there — the catalogue carries a `sizeof` the
compiler computed for every parameter and every return, and that number
is what the engine has always actually run on. Cells are that many
bytes. A delivery copies that many bytes. A task is allocated for
exactly that many. **The check stops asking a question the engine does
not otherwise care about.**

**Names stay, for people.** Every refusal names both types *and* both
widths, because *"box returns a colour, slot takes a point"* does not
tell anybody why those disagree and *"16 bytes against 12"* does. The
name is reported, not decided upon.

| | width comparison | name comparison |
|---|---|---|
| two identical layouts under different names | **wire** | refused — the author writes an adapter box that does nothing |
| an integer into a double | refused, 4 against 8 | refused |
| an integer into a float, same machine | **wires, silently wrong** | refused |
| two structs, same fields, different order | **wires, fields scrambled** | refused |

**Why the weaker rule is the chosen one.** Every stricter check
eventually makes somebody write a box that takes one type, returns
another, and does nothing — an adapter written for no reason except to
satisfy the engine. Somebody bringing C they already had should be able
to bring it unchanged, and *the bytes must be the same count* is a rule
they can hold in their head while doing it.

**What is not caught, stated plainly rather than discovered later.**
Two types of the same width are interchangeable, silently and
completely. On this machine that means a 32-bit integer against a
32-bit float, and a 64-bit integer against a double against a pointer.
A `1.0f` delivered into an integer slot arrives as `1065353216`, with
no error anywhere, ever. The delivery path is a memory copy and it
copies whatever it is told to.

This is the same bargain the engine makes everywhere else, one step
further. Order, timing and pairing were already sold to keep every core
busy; this sells the last thing standing between a value and a wire
that fits it.

### Orderings

A comparator asks "is this below, equal to, or above the threshold?" —
which the engine cannot answer for a type it knows only as a byte
count.

```
   value ──→ ┌─────────────┐ ──→ below
             │ comparator  │ ──→ equal
   threshold │             │ ──→ above
   (a port)  └─ asks the ordering for this type
```

A value type that wants to be compared supplies one — a function beside
it in the same source file, recognised by its name. The catalogue
records which types have one, and a comparator whose type has none is
refused at placement, the moment its catalogue row is first consulted.
It cannot be refused at build time, because the generator never sees a
map and so never learns that anybody wanted to compare that type.

### Field tables

A fixed value is written in a map file as text — `{ 5, 2.0, "hey" }` —
and has to become bytes in a port. That needs the struct's field list:
per field a name, an offset, a size, and a kind, with every offset and
size an expression the compiler computes, so a padded struct with a
seven-byte hole in it reads correctly.

**Nothing in the wire check consults this.** It is emitted for two
other customers: the reader that turns brace text into bytes, and the
writer that turns bytes back into text when a running program is
written out. It is also, if anybody ever wants layout disagreements
caught, everything a stricter check would need — already emitted, sitting
unconsulted.

## Suggested implementation steps

1. The wire check compares two sizes, at every place a wire is checked:
   the loader, the operation a person calls while editing, and the
   comparator's return-type check.
2. Refusals report both names and both widths.
3. Orderings, recognised by name, recorded per type, refused at
   placement.
4. Field tables emitted per struct, and one reader that walks one to
   turn text into bytes.
5. A test that two identically-laid-out, differently-named structs wire
   together and deliver byte-identical values — the capability this
   buys and the reason for the rule.
6. A test that two different widths are refused, naming both.
7. A test that two same-width structs with reordered fields **wire, and
   deliver scrambled fields.** Written deliberately, so that whoever
   finds it later finds a decision rather than an oversight.

## Open questions

- *Should the type names ship in the ordinary build?* They exist only
  for messages, and messages are read by somebody with a laptop
  attached. Dropping them from the ordinary build saves a string per
  parameter across every box in the system, at the cost of a refusal
  that can only say "4 bytes against 8" to the person holding the
  device. Leaning toward keeping them, because the person holding the
  device is exactly who this project is for.
- *What happens to a fixed value written for a struct whose fields
  later change?* The text no longer matches the field table, which the
  reader should refuse loudly rather than partially fill. It is the
  shape of error somebody hits while editing on the device, so the
  message matters more than usual.

## Blocked by

302.

## Blocks

306, 307, 308, and phase 4's compile pipeline, which cannot exist
safely under name comparison.

## Related

- [302 — The generator](302-the-generator.md), which emits all of this
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md),
  the check's home
- [308 — The kinds that pick an exit](308-the-kinds-that-pick-an-exit.md),
  where orderings get used
