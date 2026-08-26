# 306 — The demos, and the thing that runs them

## Current behavior

Three phases of machinery and no single place that shows what any of it does.

## Intended behavior

**One runnable demonstration per phase, and a script at the project root that
asks which one to see.**

Demos are part of the deliverable, not a development artifact. They are how the
project is shown to somebody, they are released with it, and they are updated as
it changes.

**They show numbers and pictures, not descriptions.** A demo that prints "the
scene grammar assigns biomes" has said nothing. One that prints the biome
distribution across two thousand characters, names the five commonest unglossable
components, and opens a page with real fields on it has shown the thing working.

**Each demo uses the phases below it.** That is the point of demonstrating by
phase: phase 2's demo runs on records phase 1 produced, and phase 3's demo runs
the whole pipeline. A phase demo that avoids the earlier phases is testing
nothing about how the parts fit.

### What each one shows

**Phase 1 — The Ink.** The two archives read, and how long that took. The join,
and what fell out of it on each side. Every path in the archive parsed and
flattened, with the counts. A character drawn to a real PNG, with its size and
what the compressor achieved against raw. This phase's claim is *the data is in
here and it can be drawn*, and those numbers are that claim.

**Phase 2 — The Meaning.** A handful of characters taken all the way to a scene
and a prompt, printed in full, with the reasoning visible: chosen biome and why,
which components became subjects, which were demoted for being phonetic, what
object each named stroke carries. Then the biome distribution across a large set,
and the unglossable-component leaderboard. Then real fields and real arrow layers
written out, at thumbnail size beside the characters, because this is the phase
where looking is the test.

**Phase 3 — The Machine.** A complete set generated end to end, in parallel, with
the timing and the report. A workflow printed so its shape is visible. The
gallery built and opened. The documentation site built. This one is the product.

### The runner

`run-demo` at the project root: lists the demos that exist, asks for a number,
runs that one. Each demo's own description comes out of the demo file's header
comment, so what a demonstration shows is written in the demonstration, and there
is no second list to drift out of date.

## Suggested implementation steps

1. **`issues/completed/demos/phase-N-<name>.sh`**, one per phase, each with a
   `DIR` at the top that is overridable by an argument, as every script here is.

2. **A demo that needs the archives and cannot find them says which command
   fetches them and stops.** It does not fetch them itself — a demonstration that
   silently downloads thirty megabytes is a demonstration that has surprised
   somebody.

3. **Demos write into `tmp/shared-memory/`**, which is RAM, and never into the
   repository. Running a demo must not modify the project.

4. **`run-tests` at the root as well**, running every test file in order and
   summarising. Tests are cheap and there should be many; there needs to be one
   command that runs all of them.

## Related

`docs/006` — the phases. Every previous ticket — this is what shows them.
