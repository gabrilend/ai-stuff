# 101 — The Reversible Patch Component

**Phase:** 1 — The patch machine
**Blocks:** every other issue in the project
**Blocked by:** nothing

## Current behavior

The Xonotic source sits under `source/` as two shallow clones — the engine and
the game data — and is gitignored. There is no way to change anything in it that
survives a re-clone, and no way to change anything in it that can be taken back
out. Any edit made today is indistinguishable tomorrow from code Xonotic shipped.

## Intended behavior

A customization is a **pair of functions over the source tree**:

```
apply:    pristine tree     ->  customized tree
unapply:  customized tree   ->  pristine tree      (exact inverse)
```

Two properties, both enforced by structure rather than by anyone remembering:

- **Idempotent.** Applying twice equals applying once. Enforced by a guard that
  checks for the un-patched shape before editing, so a second run is inert.
- **Exact inverse.** Unapplying an applied patch returns the tree to precisely
  what upstream shipped, byte for byte.

Every patch carries a header recording what file it targets, what upstream does
today, what we change it to and why, the unique pattern the edit keys on, a
witness string present only in the patched form, and the number of times the
anchor is expected to match. The header is not documentation — it is the input
the registry generator and the staleness auditor read.

Each patch wraps its replacement text in a marker unique to that patch, in the
target file's own comment syntax. The marker is what the inverse locates, so the
inverse cannot false-match either upstream text or a sibling patch, no matter how
upstream reflows the code around it. The same marker doubles as the witness, so
the "is this applied?" probe and the inverse agree by construction rather than by
being kept in sync.

Patches are grouped by **when they fire**, one prefix per tier:

| Prefix | Fires | Targets | Reverts? |
|---|---|---|---|
| `P` | after clone, before build | Xonotic source we do not own | **yes, exactly** |
| `I` | after build, on the installed tree | our own installed artifacts | no, re-running is idempotent |

Only the `P` tier touches code belonging to someone else, so only its revert has
to be exact. A third tier for runtime configuration is not wired, because this
project has no deploy step that would establish its precondition.

## Suggested implementation steps

1. Write the orchestrator that sources every patch file by glob, so that adding a
   file *is* registering it and there is no manifest to keep in sync.
2. Declare the per-profile patch selections as an associative array — the one
   genuinely declarative input, kept as data the drivers read rather than as a
   procedure anyone follows.
3. Write the apply and unapply drivers. Each walks the active profile's list and
   dispatches by naming convention, so the function name is the registration.
4. Make the unapply driver report only patches whose content actually changed, by
   comparing the version-control status of the tree before and after each one.
   "Nothing printed" then becomes a machine-derived fact rather than a guess.
5. Write the tree reset, which drives both clones back to their recorded commit.
   It must be safe to run unconditionally, because it is the backstop for a build
   killed in a way that bypasses the cleanup handler.

## Related documents

- The patch-system skill this is assembled from, which describes the component
  shape and the wiring in general terms.
- `docs/002-datapath-the-input-path.md`, which establishes that the project's
  changes land in three different places and therefore need a mechanism that does
  not care which.

## Notes

The load-bearing line of the whole design is the gitignore entry for `source/`.
Everything else is a consequence of the cloned tree being disposable. A
customization that survives in the repository's history is, by construction, a
bug — either a failed unapply or a hand edit that should have been a patch.
