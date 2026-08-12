# 304 — The generator in the build

## Current behavior

**The generator exists and nothing runs it.**

## Intended behavior

**It runs before the compiler, every time, and a failing run leaves the
previous output untouched.**

```
   box sources changed?
        │
        ▼
   generator runs
        │
        ├── failed ──→ stop. write nothing into place.
        │              the last good catalogue is still there,
        │              and the build that used it still builds.
        │
        └── succeeded ──→ write into place, then compile
```

**You can never compile against a stale catalogue.** That is the whole
guarantee this issue buys, and it is bought by writing to a scratch
name and moving it into place only on success. A generator that
half-writes its output on the way to failing leaves a catalogue that
compiles and is wrong, which is the worst of the three possible states.

**The build already knows how to do this.** The work directory sits in
RAM behind a link the build resolves once (see the completed build
system issue), and moving a finished file over an old one on the same
filesystem is the same trick the lab-side scripts use to replace
themselves while running.

| when | what runs |
|---|---|
| a box source changed | the generator, then the compiler |
| only kernel sources changed | the compiler alone |
| the generator itself changed | the generator, then everything downstream of it |

That last row is the one that gets forgotten. The generated files
depend on the program that writes them, not only on the files it reads.

**Two build flavours, one catalogue.** The ordinary build and the debug
build differ in what the kernel carries — the snapshot before each box
call, the transcript ring, the timestamps on error records — and none
of that changes what a box *is*. So the catalogue is generated once and
both flavours compile against it.

## Suggested implementation steps

1. A build rule producing the generated files from the box source
   directory, with the generator itself listed among what they depend
   on.
2. Write to a scratch name, move into place only on success.
3. A target that runs the generator's print-what-it-saw mode without
   emitting anything, for diagnosing a build failure.
4. A test that a deliberately broken box source fails the build, writes
   nothing, and leaves the previous catalogue intact and usable.
5. A test that touching the generator rebuilds the catalogue even when
   no box source changed.

## Open questions

- *Does the device rebuild its own catalogue?* Phase 4's compile
  pipeline lets somebody write a box at a touchscreen, and that box
  needs a call site and a catalogue row like any other. Either the
  generator runs on the device — it is a text-reading program, so it
  could — or on-device boxes reach the engine by a second route, and a
  second route is exactly what phase 2 spent an issue eliminating.
  Leaning strongly toward the generator running on the device, and it
  wants deciding before phase 4 rather than during it.

## Blocked by

302.

## Blocks

312.

## Related

- [302 — The generator](302-the-generator.md), what this runs
- [103 — Project build system](completed/103-project-build-system.md),
  the build this extends
