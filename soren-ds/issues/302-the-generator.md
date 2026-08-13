# 302 — The generator: one call site per box, and a catalogue

## Current behavior

**The engine has one place where it calls a box, and one line of C
cannot be every signature at once.**

A worker holds a task and must call the function it names. In C,
calling through a function pointer requires the signature written
literally at the call site — the compiler has to know what goes in
which register and what comes back. The worker cannot learn that at
runtime, and every box has a different signature.

## Intended behavior

**A program reads the box sources and writes two things nobody edits: a
call site per box, and a catalogue of every box.**

```
   src/boxes/*.c
        │
        │  read (never guessed at — see below)
        ▼
   ┌──────────────────────────────────────────────┐
   │  a call site per box                         │
   │    unpack the task's bytes into real          │
   │    arguments, call the function, put the      │
   │    return value back. all with the same       │
   │    outside shape: takes a task, returns       │
   │    nothing.                                   │
   ├──────────────────────────────────────────────┤
   │  the catalogue                                │
   │    name │ call site │ each parameter's type   │
   │         │ and size │ return type and size │   │
   │         │ exact task size │ its ordering      │
   └──────────────────────────────────────────────┘
```

**Every call site has the same outside shape and different insides.**
So one table holds all of them, a station holds a pointer to its own,
and the whole engine contains exactly one place where a box is called.
By the time that pointer reaches a worker, the signature has already
been consumed and nobody has to ask.

**The box function itself is untouched.** It takes real types by value
and returns one. The byte-copying lives outside it, in generated code
no person writes, and the compiler will almost certainly fold the box
into its call site so the wrapper costs nothing.

**Every size is a `sizeof` expression the C compiler computes, never a
number the generator worked out.** The generator cannot guess wrong
because it does not guess. This is the single property that makes the
whole arrangement trustworthy, and it is why the catalogue is emitted
as C rather than as data.

**Copies, not casts.** A task packs its values back to back, so a
64-bit value following a 32-bit one can sit at an address the hardware
would refuse to load from directly — and on this device, refusing means
a fault rather than a slowdown. The generated call sites copy bytes in
and out rather than pointing at them in place.

### Why not the alternatives

| instead | what it costs |
|---|---|
| every box takes an array of pointers and casts inside | every box author hand-writes casts — more unchecked code, not less — and values stop being passed by value |
| build the call frame at runtime from a description | an external library, roughly fifty times the per-call cost, and hand-written assembly per architecture, because "integers in one register file, floating point in another, large structs on the stack" cannot be said in portable C |
| a macro per box instead of a program | works, and leaves macros in every source file for the next reader to decode. One program that reads is better than one macro expanded many times. |

### It does not need to understand C

That distinction is what makes this tractable. A real C parser has to
track type names to know whether a construct is even a declaration,
which is a large program. This one recognises three things in files it
is pointed at: function declarations, struct definitions, and orderings
by their name suffix. It blanks comments, string contents, and
preprocessor lines first — keeping the line numbers — so a brace inside
a string cannot throw off everything after it.

**It fails rather than guesses.** A declaration it cannot read stops
the build and names the file and the line. A generator that quietly
skips what it does not understand produces a catalogue with a hole in
it, and the hole surfaces much later as a box that cannot be found by
name — pointing at the map, which is not where the problem is.

**Reading and writing stay separate.** The reader produces a
description; the writers consume one. So the reader can be tested
against source text alone, the writers against a description built by
hand, and a build problem can be diagnosed by asking the reader to
print what it saw rather than by staring at what it emitted.

## Suggested implementation steps

1. The reader: blank comments and strings, find top-level declarations,
   classify each as a box, a helper, an ordering, or a struct.
2. A mode that prints what the reader saw, exposed as its own build
   target.
3. The call-site writer, one per box, each carrying a comment naming
   the declaration and line it came from.
4. The catalogue writer, with lookup by name, every size a `sizeof`
   expression, and every type carried as text beside its size.
5. Replace phase 2's hand-supplied shapes with catalogue lookups —
   this is the moment placing a station by the name "add" becomes
   correct by construction.
6. Tests: several declarations in one file, a struct returned by value,
   a function returning nothing, a declaration spanning several lines,
   a brace inside a string, and a call site proven to produce the same
   answer as calling the function directly.

## Open questions

- *Is the describe mode worth its weight on the device?* The generator
  has to run there eventually (304), and printing what it saw is how a
  build problem gets diagnosed by reading findings rather than emitted
  C. On a laptop that is free; on a handheld it is a screen somebody
  has to read it on.
- *Type names are carried as text for error messages — how much text?*
  Enough to say "returns a 32-bit integer, slot takes a 64-bit float",
  which four-bytes-versus-eight cannot say. That is a size on the
  device's memory budget, small but not zero, and it may want to be
  debug-build only.

## Blocked by

301.

## Blocks

303, 304, 306, 307.

## Related

- [301 — What a box source is](301-what-a-box-source-is.md), the input
- [304 — The generator in the build](304-the-generator-in-the-build.md),
  where it runs
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md),
  which reads the catalogue to check every wire
