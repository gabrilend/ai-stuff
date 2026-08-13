# 304 — The generator in the build

## Current behavior

**The generator exists and nothing runs it.**

## Intended behavior

**It runs before the compiler, every time, and a failing run leaves the
previous output untouched.**

**And it is a C program, not a script.** That decides more than it
looks like it does. A generator written in a scripting language means
every machine that builds this needs that language installed, even
though none of it runs on the device — and, more importantly here, it
means the generator is a *build tool* rather than something the kernel
can call. Written in C with no dependency on the engine it feeds, it is
compiled by the same compiler that will compile its output, and it is
callable at runtime.

So the build gains one stage rather than one step:

```
   compile the generator ──→ run it ──→ compile everything else
```

There is no bootstrap problem, because the generator depends on nothing
it generates.

The honest majority of that work is not the parsing. A scripting
language supplies growable strings, hash lookup, and pattern matching;
C supplies none of them. A few hundred lines of support underneath —
a growable output buffer, an arena so nothing has to be freed one piece
at a time, and a string scanner — is the difference between a
translation and a thicket, and each deserves its own test, because
everything above assumes they are right and a bug there surfaces as
garbled C hundreds of lines away.

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

- *Where does the on-device build put its output?* The generator runs
  on the device in phase 4, which means it writes C somewhere and a
  compiler reads it. The RAM-backed tier is the obvious home and it is
  also the one that empties on reboot, which is the right lifetime for
  something regenerable. Phase 4 owns the answer; this issue owes it the
  property that a failed run leaves nothing loadable, which matters far
  more there than here.
- *Does the on-device path use the same describe mode?* It should —
  a second way of reporting what the parser saw is a second thing that
  can disagree — but the laptop reads a terminal and the device has a
  touchscreen, and nobody has decided what that looks like.

## Blocked by

302.

## Blocks

312.

## Related

- [302 — The generator](302-the-generator.md), what this runs
- [103 — Project build system](completed/103-project-build-system.md),
  the build this extends
