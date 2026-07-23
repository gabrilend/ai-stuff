# Architecture

Symbeline Rumble produces two artifacts from one source tree:

- A **Nintendo DS ROM** (`build-nds/symbeline.nds`), built with devkitARM and
  libnds. The canonical target.
- A **native Linux/ARM binary** (`build-native/symbeline`), built with the
  host toolchain against a portable backend (raylib or SDL2; chosen in
  phase 1).

The trunk source is DS-shaped: fixed-point math, hard memory budgets, no
threads, hardware-3D-engine submission model. The native build inherits that
shape and only diverges where the DS technique is genuinely impossible or
genuinely worse on a modern device.

## The patch system

Modeled after `/home/ritz/games/azeroth-core/wow-chat-2026/patches/`. Each
divergence between the targets is expressed as a paired apply/unapply
function in `patches/`. The build runs:

```
apply_patches_begin   →   make/cmake   →   unapply_patches_begin   →   apply_patches_end
```

After every build, the source tree returns to its canonical DS-shaped form.
Divergent code does not live in the trunk.

### Patch file layout

```
patches/
├── patches.sh                  central manifest (PHASE_BEGIN_PATCHES, PHASE_END_PATCHES)
├── B001-<name>.sh              source-modifying patch, apply pre-build
├── B002-<name>.sh
├── ...
├── E001-<name>.sh              post-build patch (config, symlinks, assets)
├── E002-<name>.sh
└── E-patches.sh                end-phase loader
```

Each `B###` and `E###` file exposes:

```bash
patch_B001_<name>()    { ... }     # idempotent application
unpatch_B001_<name>()  { ... }     # idempotent reversal
```

`patches.sh` declares per-profile patch lists:

```bash
declare -A PHASE_BEGIN_PATCHES=(
    ["nds"]="B001 B002 B005"
    ["native"]="B003 B004 B006 B007"
)
declare -A PHASE_END_PATCHES=(
    ["nds"]="E001"
    ["native"]="E002 E003"
)
```

The dispatch is a table lookup (per the global preference for dispatch tables
over conditionals), not a chain of `if [[ $PROFILE == ... ]]`.

## The platform seam

A single header `src/platform.h` (eventually `src/01-platform.h` per the
indexed-filename rule) declares every operation that *could* diverge between
DS and native:

```
struct platform_screen_pair { ... };   /* two virtual screens (DS = real, native = split window) */
struct platform_input       { ... };   /* buttons + stylus, normalized */
struct platform_audio       { ... };   /* fixed-channel mixer interface */
struct platform_file        { ... };   /* save data, asset access */
struct platform_time        { ... };   /* tick, frame counter */
```

The DS implementation is the trunk default; the native implementation arrives
via a `B###` patch when the `native` profile is selected. Gameplay code
includes only `platform.h` — never `nds.h` or SDL headers.

## Memory and budgets (DS-side, inherited by native)

| Pool          | DS budget    | Native behavior                          |
|---------------|--------------|------------------------------------------|
| Main RAM      | 4 MiB        | Mirrors the DS allocator; cap enforced.  |
| VRAM (texture)| ~512 KiB     | Native uses GPU memory but observes cap. |
| VRAM (3D)     | ~144 KiB     | Same.                                    |
| IWRAM (ARM9)  | 32 KiB hot   | Native ignores (no equivalent).          |
| Frame budget  | ~16.67 ms    | Same target; native often beats it.      |
| Triangles     | ~2 048/frame | Native could exceed but does not, for parity. |

The native build deliberately *honors the DS budgets*. If a scene cannot run
on DS, it cannot run on native either. This is parity, not pessimism — it
keeps the divergence grid honest.

## Threading

The DS has no preemptive threading; the trunk reflects that. The main loop
is cooperative, with hardware interrupts for vblank, hblank, and timers.
The native build uses a single thread to preserve determinism. Worker
threads, if ever added, will be patches with a documented re-convergence
plan (likely "never re-converge — DS stays single-threaded").

## Math

Gameplay is fixed-point only; see `008-fixed-point-math.md`. Asset authoring
tools may use floats, but the asset pipeline emits fixed-point values to
binary asset files consumed by the trunk.

## Build entry points

- `scripts/symbeline-build nds` — full NDS build.
- `scripts/symbeline-build native` — full native build.
- `scripts/symbeline-build both` — runs both sequentially.
- `scripts/symbeline-run nds` — boot last NDS build in melonDS / no$gba.
- `scripts/symbeline-run native` — boot last native build.

All scripts honor the `${DIR}` argument convention (per global rule). All
scripts return the trunk to clean state, even on build failure.

## Why this shape

A single divergent codebase tends toward `#ifdef` sprawl, which tends toward
two codebases pretending to be one. The patch-system shape forces every
divergence to be *named*, *reversible*, and *visible in the divergence
grid* (`005-divergence-grid.md`). The trunk reads as one program; the patch
set reads as the index of how the targets disagree.
