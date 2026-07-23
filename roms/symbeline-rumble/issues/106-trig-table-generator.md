# 106 — Trig table generator

**Phase:** 1
**Blocked by:** 105 (the table is consumed by `fx_sin`/`fx_cos` declared
in `src/00-fixed-point.h`).
**Blocks:** any gameplay needing angles (pathing direction, aiming,
camera rotation — all of phase 2 onward).

## Current behavior

`fx_sin` and `fx_cos` are declared in `src/00-fixed-point.h` (per issue
105) but have no table to read from. Calling them will not link.

## Intended behavior

A build-time Lua script `scripts/gen-trig-table.lua` emits a C source
file `src/00-fixed-point-trig-table.c` containing:

- `const int16_t fx_sin_table[256]`: 256 entries of Q1.15 sine values,
  one per 1/256th of a turn.
- A comment header noting the generation parameters and date.
- A static_assert (or `_Static_assert`) checking entry count.

The Lua script:

- Is invoked from the build (both profiles) before compile.
- Honors the `${DIR}` argument convention (global rule).
- Uses LuaJIT-compatible syntax (no Lua 5.4 features).
- Uses Lua's `math.sin` (host float math) at generation time, then
  rounds to Q1.15. Output is integers; runtime never sees a float.
- Is idempotent: if the output file already exists and is byte-for-byte
  identical to what would be regenerated, no rewrite.

`src/00-fixed-point.c` implements `fx_sin` / `fx_cos` reading from the
table with linear interpolation between adjacent entries.

`fx_atan2` (CORDIC) and `fx_sqrt` (Newton-Raphson, table-seeded) are also
implemented in `src/00-fixed-point.c`. `fx_sqrt`'s initial-guess table is
also emitted by this generator into `src/00-fixed-point-sqrt-seeds.c`.

## Suggested implementation steps

1. Author `scripts/gen-trig-table.lua`:
   - Vimfold structure per the global rule.
   - Top-of-file CEO description.
   - Generates sine table, sqrt seed table, writes both as
     `static const int16_t name[N] = { ... };` arrays.
2. Add invocation of `gen-trig-table.lua` to the build entry points
   (`scripts/symbeline-build`), before the patch-apply step.
3. Implement `fx_sin`, `fx_cos`, `fx_atan2`, `fx_sqrt` in
   `src/00-fixed-point.c` using the emitted tables.
4. Add `tests/00-fixed-point-trig-accuracy.c`: verify
   `fx_sin(quarter_turn) ≈ FX_ONE` (within table precision),
   `fx_cos(zero) == FX_ONE`, etc. Tolerance is documented.

## Why Lua for the generator

The global preference for build-time tooling is Lua/LuaJIT. The generator
is exactly that: a build-time tool. The generator never runs on the DS.
This is the appropriate place for Lua in the project shape.

## Deliverable artifacts

- `scripts/gen-trig-table.lua`
- `src/00-fixed-point-trig-table.c` (generated; in `.gitignore`).
- `src/00-fixed-point-sqrt-seeds.c` (generated; in `.gitignore`).
- `src/00-fixed-point.c` (filled in, replacing the empty version from 105).
- `tests/00-fixed-point-trig-accuracy.c`

## Related documents

- `docs/008-fixed-point-math.md` — trig section.
- Memory: project rule on no-float-in-gameplay (the generator emits
  integers; the runtime never sees floats).
