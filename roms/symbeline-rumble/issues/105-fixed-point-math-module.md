# 105 — Fixed-point math module

**Phase:** 1
**Blocked by:** 102 (project structure).
**Blocks:** 104 (platform seam uses these types), 107, 108, every gameplay
issue in every phase.

## Current behavior

The fixed-point design is specified in `docs/008-fixed-point-math.md` but
no header or source file exists. Gameplay cannot be written until the
types and arithmetic macros exist.

## Intended behavior

A single header `src/00-fixed-point.h` declares:

- `fx_t`, `fxw_t`, `fxa_t`, `fxsmall_t` typedefs.
- Conversion macros: `FX_FROM_INT`, `FX_TO_INT`, `FX_ROUND_INT`, similar
  for `fxw_t`, `fxa_t`, `fxsmall_t`.
- Arithmetic macros / inline functions: `FX_MUL`, `FX_DIV`, plus the
  trivial `FX_ADD`/`FX_SUB`.
- libnds interop helpers `fx_to_libnds`, `libnds_to_fx`, declared only
  under `#ifdef SYMBELINE_PROFILE_NDS`.
- Native interop helper `fx_to_float`, declared only under
  `#ifdef SYMBELINE_PROFILE_NATIVE`. **This is the only float in the
  entire codebase outside the asset pipeline.**

A companion source file `src/00-fixed-point.c` is empty for now — all
operations are macro/inline. A future tick may move some to `.c` if
codegen suffers.

### Trig and sqrt

These are declared in `src/00-fixed-point.h` but their tables are
generated in issue 106 (`scripts/gen-trig-table.lua`). The header
declares:

```c
fx_t   fx_sin   (fxa_t turn);
fx_t   fx_cos   (fxa_t turn);
fxa_t  fx_atan2 (fx_t y, fx_t x);
fx_t   fx_sqrt  (fx_t x);
```

The CORDIC `fx_atan2` and Newton-Raphson `fx_sqrt` implementations live
in `src/00-fixed-point.c` once issue 106 emits the seed tables.

## Suggested implementation steps

1. Author `src/00-fixed-point.h` with the typedefs, conversion macros,
   and arithmetic macros from `docs/008-fixed-point-math.md`.
2. Author `src/00-fixed-point.info.md` documenting each macro's input
   and output ranges, and the Q-format choice rationale.
3. Author `tests/00-fixed-point-mul-overflow.c` and
   `tests/00-fixed-point-div-precision.c`. These tests run on the
   `native` profile and pin behavior at the Q16.16 boundaries
   (`FX_MUL(FX_FROM_INT(180), FX_FROM_INT(180))` should not overflow;
   `FX_MUL(FX_FROM_INT(200), FX_FROM_INT(200))` should be documented as
   overflowing-by-design). The point of these tests is to break the
   build if someone changes the Q-format without noticing.
4. Author `tests/00-fixed-point-libnds-interop.c` (NDS-profile-only)
   verifying `fx_to_libnds(libnds_to_fx(v)) == v` for representative
   values.
5. Bump `.file-index-counter` to 0 (this is index 00; it lives below the
   platform seam because the platform seam uses these types).

## Deliverable artifacts

- `src/00-fixed-point.h`
- `src/00-fixed-point.c` (initially empty)
- `src/00-fixed-point.info.md`
- `tests/00-fixed-point-mul-overflow.c`
- `tests/00-fixed-point-div-precision.c`
- `tests/00-fixed-point-libnds-interop.c`

## Related documents

- `docs/008-fixed-point-math.md` — the design spec this issue implements.
- Memory: `project_symbeline_rumble_dual_target.md` (no-float rule).
