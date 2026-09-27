# 301 — What a box source is

## Current behavior

**Built and tested on the twin.** Box sources live in `src/boxes/`, found
by where they live: the generator reads every `.c` directly in that
directory, so a box the build did not see cannot exist. The rules are in
the directory's own `src/boxes/000-README.md`, beside the files somebody
adding a box will be looking at. Phase 2's hand-written starter library
is gone; its functions are now `src/boxes/062-arithmetic.c`, and their
records are written by the generator. Beside them: `063-text.c` (text as
a 64-character value type, with an ordering), `064-launch.c` (310),
`065-calibration.c` (308's two boxes), and `073-shapes.c` (303's width
demonstration).

Box sources are never compiled on their own. The generated catalogue
includes each one exactly once, and both the kernel's and the twin's
builds skip the directory — so the four files compile into the kernel
image with the cross-compiler, which checks every box against the
kernel's rules (no floating point, no standard library) on every build.

Test material for every broken rule is in `twin/tests/074-test-generator.c`.

## Intended behavior

**A box is a C function, and that is the whole description.**

```
   src/boxes/arithmetic.c
   ┌────────────────────────────────────────────┐
   │  int add(int left, int right)              │  ← this is a box
   │  {  return left + right;  }                │
   │                                            │
   │  static int helper(int x)                  │  ← this is not
   │  {  return x * 2;  }                       │
   └────────────────────────────────────────────┘
              │
              │  the generator reads it (302)
              ▼
     name "add", two parameters of sizeof(int),
     returns sizeof(int), one call site emitted
```

Nothing is written down twice, so nothing can disagree. The shape comes
from the compiler, which is the only thing that actually knows it.

**Boxes are discovered by where they live, never listed.** Anything in
the box source directory is a box source. A box cannot exist that the
build silently did not see, and adding one is adding a file.

| in a box source file | what it becomes |
|---|---|
| a function anyone can call from outside | **a box** |
| a function marked private to the file | a helper. Not a box. |
| a function whose name ends in `__compare` | an ordering, used by a comparator. Not a box. |
| a struct definition | a value type, with a size and a field list |

**The rules a box source has to follow**, each one there because
breaking it produces something the engine cannot carry:

| rule | why |
|---|---|
| a value type is a struct, not a bare pointer | a value on a wire is copied; a pointer copies the address and shares the thing |
| a box may not return a string | borrowed memory has no owner, and the engine would not know when to release it |
| every parameter is named | the generator needs the name for its error messages, and an unnamed parameter is usually a mistake |
| a box may not remember anything between calls | two cores can be inside it at the same instant (phase 2's 209) |
| a box may never block | a core that cannot progress is a core not running the ten things that are ready |

The last two are the load-bearing ones and **nothing enforces them.** A
box with a counter inside it, or one that waits on a device, will be
wrong under load and no part of the system will say so. A linter that
refused both would move them from discipline into the build, and the
generator already reads these files — worth its own issue when
somebody has been bitten once.

## Suggested implementation steps

1. Fix where box sources live, and make it a location rather than a
   list, so a box cannot be invisible to the build.
2. Write the rules above into the directory's own header comment, since
   that is where somebody adding a box will be looking.
3. Convert phase 2's starter library into box sources of this shape,
   and delete the hand-written shapes beside them.
4. A box source that exercises each rule's violation, kept as the test
   material for the generator's refusals in 302.

## Open questions

- *Do boxes written on the device follow the same rules?* They must, or
  there are two kinds of box. But a person authoring at a touchscreen
  gets the refusal much later than somebody running a build, so the
  message matters more. Phase 4's compile pipeline is where that lands.
- *Should a box be able to say a parameter is optional?* Without it,
  every input must be wired before a station can ever run. With it, the
  parameter's type has to carry a "was this given" flag beside the
  value, because no spare number inside an integer honestly means
  absent. Worth having, worth its own issue.

### Proposed answers (UNVERIFIED)

1. *Same rules on the device?* Yes — the generator that enforces them is
   the same C file on both (304); phase 4 runs it on the device, so a
   refusal there is word for word the refusal here.
2. *Optional parameters?* Not built. Proposed: a value type with a
   `given` byte beside the value (`struct maybe_int { int64_t value;
   uint8_t given; }`), written by whoever wants optionality, rather than
   an engine feature — it needs nothing new and says what it means.

## Blocked by

Phase 2's engine, which defines what a box has to look like from the
inside.

## Blocks

302, 303, 310.

## Related

- [302 — The generator](302-the-generator.md), which reads these
- [212 — Maps built by hand](212-maps-built-by-hand.md), whose
  hand-written shapes this deletes
- [003 — Threading model](../docs/003-threading-model.md), where the
  two unenforced rules come from
