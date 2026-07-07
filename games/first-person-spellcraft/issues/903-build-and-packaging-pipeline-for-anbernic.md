# 903 — Build & packaging pipeline for Anbernic

> **Phase:** 9 — Platform & Packaging
> **Role in phase:** the machine that turns the whole game into one thing you can
> hand to a person. This is a **large** issue, split into two sub-issues that can
> be built and tested independently:
> - **903a** — asset bundling & the portable `${DIR}`-relative run/launcher script.
> - **903b** — the LuaJIT-on-ARM build & the installable Anbernic image/app artifact.
>
> This parent describes the pipeline as a whole and the seam between its halves.
> **Blocked by (within phase):** 901 (needs the target profile: arch, asset-size
> ceiling). **Feeds:** 904 (an artifact to give away), 906 (the demo).
> **Depends on (across phases):** all — it packages the *whole* Phases 1–8 game.

## Current Behavior

None of this exists yet. The game (as it comes to exist through Phases 1–8) runs
only from a developer's source tree on a developer's machine. There is no bundling
step, no cross-build for ARM, no installable artifact, and no launcher that would
let a handheld start the game. Nothing here can be given to anyone.

## Intended Behavior

A single pipeline takes the LuaJIT source of Phases 1–8 plus every asset and
produces **one installable artifact** shaped for a target Anbernic model, plus a
**portable launcher** the device can start from any directory. The pipeline reads
the target profile from issue 901 and refuses (loudly) to produce an artifact that
the budget validator says will not fit — no quiet trimming.

The pipeline is two stages that meet at a **bundle manifest**:

```
  source + assets ──903a──►  bundle manifest ──903b──►  installable artifact
                   (gather,   (every asset,    (cross-   (app dir / image +
                    normalize   ${DIR}-         build for  portable launcher
                    paths)      relative)       ARM, pack) the device menu runs)
```

- **903a** decides *what goes in* and guarantees **path portability**: every asset
  path is `${DIR}`-relative, so the game never assumes it was launched from its own
  folder. Its output is the bundle manifest and the launcher script.
- **903b** decides *how it runs on the far machine*: it cross-builds LuaJIT for the
  target ARM chip and folds the bundle into an installable image/app the device's
  menu understands.

The seam between them is the **bundle manifest**: 903a produces it, 903b consumes
it. Keeping that seam sharp means asset decisions and build decisions can change
independently.

Reproducibility is a goal: the same source + same profile should yield the same
artifact, so a copy given away is exactly the copy that was tested.

## Suggested Implementation Steps

1. Fix the **bundle manifest** structure as the contract between 903a and 903b
   (the list of code + asset files, all paths `${DIR}`-relative, dev-only files
   excluded).
2. Build **903a** (bundling + portable launcher) against that manifest.
3. Build **903b** (cross-build + packaging) consuming that manifest.
4. Wire the **budget validator (901)** into the pipeline as a gate before an
   artifact is emitted: over-budget is a spoken error, not a silent shrink.
5. Confirm reproducibility: same inputs → same artifact.
6. Provide a top-level pipeline driver script (honoring `${DIR}`) that runs 903a
   then 903b then the budget gate, so 906's demo can invoke the whole path.

## Stats / Meta

- **Kind:** delivery pipeline (large; two sub-issues).
- **Seam between sub-issues:** the bundle manifest.
- **Gate:** budget validator from 901 stands between build and artifact.

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  main datapath (bundler → cross-build → package → launcher).
- Issue **901** — supplies the target profile and the budget gate.
- Sub-issues **903a**, **903b**.
