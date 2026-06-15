# 121 — raylib Build Flag Manifest

## Status

TODO — Phase 1. Build infrastructure that supports the rest of
Phase 1 by keeping our raylib footprint honest as features come in.

## Current behavior

`scripts/deps/build-raylib.sh` invokes raylib's own Makefile with
only `PLATFORM=PLATFORM_DESKTOP RAYLIB_LIBTYPE=STATIC`. Every
optional raylib feature is left at upstream's default — including
whole modules (`rmodels`, `raudio`, `rshapes`, `rtextures`,
`rtext`) and individual file-format loaders (OBJ, GLTF, IQM, MP3,
OGG, FLAC, JPG, PNG-write, etc.). The game today only exercises a
small subset of raylib: a 3D camera, primitive draws, a hand-built
heightmap mesh, basic input. We pay link size and code surface for
everything else, and "what raylib features do we actually depend
on?" has no documented answer — only a code-search.

The raylib 6.0 release notes describe a redesigned config system
that lets each `SUPPORT_*` macro be flipped on the build
command-line via `-DSUPPORT_FILEFORMAT_OBJ=0` and similar. That is
what makes per-feature toggling tractable from our side without
patching upstream's `config.h`. We are presently pinned to raylib
**5.5** in `libs/sources`. Pre-6.0 raylib does not honor those
`-D` overrides cleanly, so on 5.5 the only correct behavior is to
build everything (upstream defaults) and leave the manifest
inert.

## Intended behavior

Two-layer behavior, gated on the raylib version pinned in
`libs/sources`:

**raylib < 6.0** (today: 5.5)
The manifest at `libs/raylib-flags` is read for documentation
value only — it does not influence the build. raylib's Makefile
runs exactly as it does today and produces a "build everything"
archive. The build scripts log a one-line note that flags are
inert at this version, so a developer flipping a row to `off` and
seeing no archive-size change is not surprised.

**raylib >= 6.0**
The manifest is the source of truth for what gets compiled in.
`scripts/deps/build-raylib.sh` reads each row and translates it
into a `-DSUPPORT_*=0` / `-DSUPPORT_*=1` define on raylib's make
invocation. Adding a new raylib feature in our code requires
updating the manifest in the same commit. A flag flipped off that
we still call surfaces as a link-time error, which is the right
failure mode per the mono-repo's "prefer breaking over fallbacks"
rule.

The version check is mechanical, not aspirational: the major
version is parsed from `libs/sources` (or, equivalently, from
`libs/raylib/.installed-version` once fetch has run) and compared
to `6` at the start of the dep build. Either both `scripts/build.sh`
and `scripts/deps/build-raylib.sh` perform the check, or one of
them performs it and exports the result for the other — the goal
is that no path through the build can apply the manifest to a
pre-6.0 raylib and silently produce nothing.

Manifest format, three settings per flag:

- `on` — we use this; the second column names the call site or
  feature that justifies it.
- `off` — we do not use this; the build turns it off (no-op on
  pre-6.0).
- `default` — we read the flag and intentionally chose to follow
  upstream (an internal tunable we have no opinion on). Kept
  distinct from `on` so the manifest distinguishes "we looked and
  agreed" from "we never looked."

## Suggested implementation steps

1. Add a version-parsing helper for `libs/sources`. The format is
   already locked in (`<name> <version> <fetch-method> <url>`), so
   extracting the raylib row's version field is a one-line awk /
   read. The check needs the major number — `5.5` → `5`,
   `6.0` → `6`, `6.1.2` → `6`.
2. Wire the check into `scripts/deps/build-raylib.sh`. On pre-6.0,
   skip any manifest pass-through and log "raylib X.Y < 6.0:
   building everything (manifest inert)." On >= 6.0, proceed to
   step 4.
3. Mirror or share the check in `scripts/build.sh` so the top-level
   build path cannot accidentally bypass it (e.g. if a future
   change adds a parallel invocation site for raylib's Makefile).
4. Inventory the upstream flag space at the pinned version. The
   canonical list lives in `libs/raylib/src/config.h` once
   `fetch-raylib.sh` has run — every `SUPPORT_*` macro defined
   there is a candidate manifest row. Even on 5.5 (where the rows
   are inert) the inventory work is useful: it documents what we
   would turn off the moment we move to 6.0.
5. Inventory our consumption. Grep `src/` for raylib symbols and
   bucket each by which `SUPPORT_*` flag it gates on. Today's call
   sites all live under `src/001-main.c`, `src/020-terrain.{h,c}`,
   `src/030-camera.{h,c}`, `src/050-units.{h,c}`. Modules to
   consider entirely off until proven otherwise: `raudio` (no
   sound), `rmodels` (we hand-roll terrain mesh and unit boxes),
   `rtext` if the demo ends up not drawing text.
6. Create `libs/raylib-flags`. One row per flag, three columns:
   `<flag> <on|off|default> <justification-or-"unused">`. Comment
   the file's format the same way `libs/sources` is commented.
7. Extend `scripts/deps/build-raylib.sh` (in the >= 6.0 branch) to
   read the manifest and compose the `-D...=0/1` arguments passed
   to raylib's Makefile. Bump the build-stamp format so a manifest
   change forces a raylib rebuild — same mechanism as the
   source-hash check, just with the flag set folded in.
8. Land the manifest with a conservative initial state: every
   flag currently exercised → `on` with a real justification,
   nothing else turned off yet. Build must pass unchanged. Then,
   after the eventual 6.0 upgrade, flip individual flags to `off`
   in follow-up commits and verify the link still succeeds and
   the demo runs.
9. Document the version-gate and the manifest in
   `docs/003-tech-stack.md` so future contributors update the
   manifest in lockstep with new raylib usage and understand why
   it appears inert on 5.5.

## Related documents and tools

- `docs/003-tech-stack.md` — vendoring section names every script
  involved.
- `scripts/deps/build-raylib.sh` — invocation site that grows the
  version check and (on 6.0+) the manifest reader.
- `scripts/build.sh` — top-level orchestrator; the version check
  must be visible from here too so no parallel invocation can
  bypass it.
- `libs/sources` — pinned-version manifest the version check
  reads.
- `libs/raylib-flags` — the new flag manifest this issue
  introduces, sibling to `libs/sources`.
- `libs/raylib/src/config.h` (after fetch) — upstream's canonical
  flag list.
- `issues/completed/101-build-system-and-raylib-bootstrap.md` —
  the vendored build the manifest plugs into; its build-infra
  addendum is the direct predecessor of this issue.

## Notes

- The flag list itself lives in a manifest file, not in this
  issue, so it stays current without immutable-issue churn. This
  issue describes the *system*; the flags themselves are data.
- Why Phase 1 instead of a later infrastructure phase: the rest of
  Phase 1 will introduce more raylib usage (text for HUD, possibly
  shapes, possibly model loading for projectiles). Catching that
  growth at the manifest level *as it lands* is cheaper than a
  retrospective audit pass after Phase 1 closes. The version gate
  means the work is non-disruptive on 5.5 and arms itself
  automatically once we move.
- Why "build everything" on pre-6.0 instead of patching `config.h`:
  patching upstream sources defeats the source-hash check in
  `scripts/deps/fetch-raylib.sh` (every fetch would look like it
  had been tampered with) and is more invasive than the gain
  warrants for a transitional version.
- Useful sanity check after the first round of flag flips on 6.0:
  archive size before vs. after. If turning off `raudio` doesn't
  shrink `libraylib.a`, the flag isn't actually being read by
  upstream's build and the manifest needs a different translation.

## Task pool integration

**Not applicable.** This is build infrastructure that runs at
compile time, not at game-runtime. The task pool only exists
inside the running game binary.
