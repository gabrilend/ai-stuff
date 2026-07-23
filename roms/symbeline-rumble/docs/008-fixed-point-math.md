# Fixed-Point Math

Gameplay math is integer math in fixed-point. Floats and doubles are
**banned in gameplay code** on both the `nds` and `native` profiles. The DS
has no FPU; the native build observes the same rule to preserve parity,
determinism, and the option of replay/netcode without a refactor.

If you need decimals, you work around them — table lookups, sub-unit
scaling, higher Q-format. Decimals are not a requirement; IEEE 754 is a
convenience the trunk does without.

## Q-formats in use

| Type        | Backing    | Format  | Range                            | Used for                                       |
|-------------|------------|---------|----------------------------------|------------------------------------------------|
| `fx_t`      | `int32_t`  | Q16.16  | ±32 768.0  step 2⁻¹⁶ ≈ 1.5×10⁻⁵   | Default for gameplay scalars (hp, atk, speed). |
| `fxw_t`     | `int32_t`  | Q20.12  | ±524 288.0 step 2⁻¹² ≈ 2.4×10⁻⁴   | World-space coordinates (the map is large).    |
| `fxa_t`     | `int16_t`  | Q1.15   | ±0.999…  step 2⁻¹⁵ ≈ 3.1×10⁻⁵    | Angles (as fraction of a turn).                |
| `fxsmall_t` | `int8_t`   | Q4.4    | ±7.9375  step 2⁻⁴ = 0.0625        | Stat modifiers (equipment deltas).             |

These match libnds conventions where possible (`f32` is its Q20.12), so
trunk values can be passed to libnds 3D APIs without per-call conversion on
the DS profile.

## Construction and conversion

```c
#define FX_SHIFT       16
#define FX_ONE         (1 << FX_SHIFT)                       /* 65 536 */
#define FX_FROM_INT(n) ((fx_t)((n) << FX_SHIFT))
#define FX_TO_INT(x)   ((int32_t)((x) >> FX_SHIFT))          /* truncates toward -∞ */
#define FX_ROUND_INT(x) ((int32_t)(((x) + (FX_ONE >> 1)) >> FX_SHIFT))
```

Literal decimals at authoring time are written as ratios: `FX_FROM_INT(3) +
FX_ONE / 4` means 3.25. There is no `FX_FROM_FLOAT` macro in gameplay code,
**by design**. The asset pipeline may use floats but emits fixed-point
binary; gameplay code consumes the binary.

## Arithmetic

```c
#define FX_ADD(a, b)   ((a) + (b))
#define FX_SUB(a, b)   ((a) - (b))

/* Multiply: a*b needs a 64-bit intermediate, then shift. */
#define FX_MUL(a, b)   ((fx_t)(((int64_t)(a) * (int64_t)(b)) >> FX_SHIFT))

/* Divide: shift up first, then divide. Loses precision for very small b. */
#define FX_DIV(a, b)   ((fx_t)(((int64_t)(a) << FX_SHIFT) / (int64_t)(b)))
```

Overflow is *not* checked at runtime — it is prevented by Q-format choice
at design time. World coordinates use `fxw_t` (Q20.12) precisely because
Q16.16 cannot represent the diagonal of a four-tile map without
risk. Tests should pin overflow boundaries (`tests/04-fixed-point-overflow.c`,
planned in phase 1).

## Trig

- `fx_sin(fxa_t turn)` and `fx_cos(fxa_t turn)` use a 256-entry table of
  Q1.15 values, with linear interpolation between entries. The table is
  generated at build time by `scripts/gen-trig-table.lua` and emitted as a
  C array.
- `fx_atan2(fx_t y, fx_t x)` uses a CORDIC-style iterative algorithm
  returning `fxa_t`. Acceptable for our path-decision math.
- `fx_sqrt(fx_t x)` uses Newton-Raphson with a table-seeded initial guess.

Angle units are *turns* (Q1.15: ±1 turn). This is not radians and not
degrees. The rationale: trig tables work nicely with powers-of-two index
counts when the input is "fraction of a turn," and we never have to
multiply by π.

## libnds interop

On the `nds` profile, `fx_t` and libnds `f32` differ only in Q format
(Q16.16 vs Q20.12). The conversion is a single shift:

```c
static inline f32 fx_to_libnds(fx_t v) { return (f32)(v >> 4); }   /* Q16.16 → Q20.12 */
static inline fx_t libnds_to_fx(f32 v) { return (fx_t)(v << 4); }
```

`fxw_t` is `f32` directly; no conversion needed for world coordinates
passed to the 3D engine.

On the `native` profile, the GPU consumes floats. The conversion is done in
the platform layer (`platform_render_*`), not in gameplay code:

```c
static inline float fx_to_float(fx_t v) { return (float)v / (float)FX_ONE; }
```

This is the **only sanctioned use of float** in the entire codebase, and it
lives behind the platform seam.

## Asset pipeline

Authoring tools (model converters, level editors, stat balancers) may use
floats freely. The build-time emitter (`scripts/emit-asset.lua` or
similar) converts to the appropriate Q-format and writes binary asset
files. The runtime consumes the binary only.

## Reviewer checklist

When reviewing gameplay code:

- `grep -nE '\b(float|double)\b'` should return zero hits in `src/`
  outside `src/platform/`.
- Any literal decimal in code (`0.5f`, `1.0`, `3.14`) is a bug; replace
  with `FX_ONE / 2`, `FX_ONE`, or a named fixed-point constant.
- Any new stat or quantity introduces a Q-format decision; document it in
  the relevant `.info.md`.

## Why this rule is strict

The whole point of the dual-target build is to keep parity. Floats break
parity (different rounding on DS's software float vs. native's hardware
float; on DS we won't even have software floats in the hot path). Floats
break determinism (replays, network sync). Floats invite "just this once"
exceptions that turn the trunk DS-incompatible.

If the rule feels expensive, it is doing its job — it is the cost of
having one source tree instead of two.
