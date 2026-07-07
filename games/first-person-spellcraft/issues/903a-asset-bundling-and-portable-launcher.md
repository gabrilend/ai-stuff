# 903a — Asset bundling & the portable ${DIR}-relative launcher

> **Phase:** 9 — Platform & Packaging · **Sub-issue of:** 903.
> **Role:** the first half of the pipeline — decide *what goes into* the artifact
> and guarantee it runs no matter which folder it starts from. Produces the
> **bundle manifest** (the seam to 903b) and the **portable launcher**.
> **Blocked by:** 901 (asset-size ceiling), 903 (the manifest contract).

## Current Behavior

None of this exists yet. Assets (as Phases 1–8 produce them: maps, art, sound,
spell/puzzle/NCP data) live scattered in the source tree, referenced however each
phase happened to reference them. There is no single gather step, no path
normalization, and no launcher — so there is nothing to hand to 903b, and any run
would assume it was started from a specific folder.

## Intended Behavior

A deterministic **asset bundler** walks the project's asset tree and produces a
**bundle manifest**: the complete list of code and asset files that belong in the
artifact, with **every path made `${DIR}`-relative** and all developer-only files
(tests, notes, scratch) excluded. Alongside it, a **portable launcher script**
starts the game honoring the project's `${DIR}` convention:

- A hard-coded `${DIR}` at the top of the launcher, overridable by a command-line
  argument, with **every path in it relative to `${DIR}`**. The game must never
  assume it was launched from its own directory — this is exactly the discipline
  that makes handheld (and later cassette) packaging honest.
- The launcher ensures any needed runtime scaffolding exists before starting
  (e.g. the RAM-backed `tmp/` symlink convention for logs), rather than crashing
  when a directory is missing.

The manifest is the **contract to 903b**: 903b consumes it and does not re-scan the
tree. Determinism matters — the same tree yields the same manifest, so the
artifact is reproducible.

Path portability is checked, not hoped: a test starts the launcher from an
unrelated working directory and confirms the game still finds its assets.

## Suggested Implementation Steps

1. Define the **bundle manifest** structure per 903's contract (files + relative
   paths + exclusions).
2. Write the **asset bundler**: walk the asset tree, normalize each path to be
   `${DIR}`-relative, drop dev-only files, emit the manifest deterministically.
3. Check the total against the **asset-size ceiling** from the profile (901); over
   ceiling is a spoken error naming what pushed it over.
4. Write the **portable launcher script**: hard-coded `${DIR}` + argument override,
   all paths relative, creates the RAM-backed `tmp/` symlink target if absent, then
   starts the game.
5. Add a **path-portability test**: launch from an unrelated directory, confirm
   assets resolve; a second test confirms the manifest is stable across two runs.

## Stats / Meta

- **Kind:** bundling + portability (pipeline first half).
- **Output:** bundle manifest (→ 903b), portable launcher.
- **Convention enforced:** `${DIR}` hard-coded + argument-overridable, all paths
  relative.

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  asset bundler and portable launcher roles.
- Parent **903**; sibling **903b** (consumes the manifest).
- Issue **901** — the asset-size ceiling this checks against.
