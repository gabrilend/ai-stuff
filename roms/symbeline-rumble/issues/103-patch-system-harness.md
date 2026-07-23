# 103 — Patch system harness

**Phase:** 1
**Blocked by:** 102 (the build script must call into this).
**Blocks:** every divergent feature in every phase.

## Current behavior

The `patches/` directory exists but is empty. The architecture commits to a
patch-driven divergence model (`docs/004-architecture.md`) but the harness
to apply, unapply, and dispatch patches has not been written.

## Intended behavior

`patches/patches.sh` is a sourceable bash file that, when sourced, makes
the following available:

- A `B###` patch loader that finds every `patches/B[0-9][0-9][0-9]-*.sh`
  file and sources it, populating `patch_B###_<name>` and
  `unpatch_B###_<name>` functions into the current shell.
- An `E###` patch loader (same shape, post-build phase).
- Two associative arrays: `PHASE_BEGIN_PATCHES[<profile>]="B001 B002 ..."`
  and `PHASE_END_PATCHES[<profile>]="E001 ..."`. Initially empty — patch
  IDs are added by feature issues in later phases.
- `apply_patches_begin`, `unapply_patches_begin`, `apply_patches_end`,
  `unapply_patches_end` functions, each of which:
  - Reads the relevant array for the active `$PROFILE`.
  - Iterates patches via a dispatch (look up `patch_${id}_*` in
    `declare -F`), not via a switch on the patch ID.
  - Logs each applied patch with its function name to
    `tmp/patches-<timestamp>.log`.
  - Is idempotent: applying twice is a no-op; unapplying twice is a no-op.

The shape is borrowed from
`/home/ritz/games/azeroth-core/wow-chat-2026/patches/patches.sh`; this
issue extracts the pattern into a reusable harness specific to Symbeline
Rumble's two profiles.

## Suggested implementation steps

1. Write `patches/patches.sh`:
   - Determine `PATCHES_DIR` via `BASH_SOURCE`.
   - Source all `B[0-9][0-9][0-9]-*.sh` files.
   - Source `E-patches.sh` if present (which itself sources `E###` files).
   - Declare the per-profile arrays empty for now.
   - Implement the four `apply_*`/`unapply_*` functions with dispatch via
     `declare -F | grep` and `${func}` invocation.
2. Write `patches/E-patches.sh`: companion loader for `E###` files.
3. Write a placeholder `patches/B000-trunk-sanity.sh` whose `patch_B000_*`
   is a no-op that writes "patch system online" to `tmp/`. This proves the
   harness works before any real divergence patch exists.
4. Add `B000` to both profiles' `PHASE_BEGIN_PATCHES` so every build
   exercises the harness.
5. Document the patch-file template in a comment at the top of
   `patches/patches.sh` (the CEO-level description: "patches/ holds
   reversible source modifications; each one applies and unapplies; the
   build runs them on either side of compile to keep the trunk clean").

## Idempotency requirements

Both `patch_*` and `unpatch_*` must:

- Detect whether their target state is already met and short-circuit.
- Use atomic file operations where applicable (write-to-tmp then rename).
- Not depend on any state external to the patch's own source files.

## Deliverable artifacts

- `patches/patches.sh`
- `patches/E-patches.sh`
- `patches/B000-trunk-sanity.sh`

## Related documents

- `docs/004-architecture.md` — patch system specification.
- `docs/005-divergence-grid.md` — every patch added in later phases must
  correspond to a grid row.
- Memory: `feedback_divergence_grid_plotting.md`.
