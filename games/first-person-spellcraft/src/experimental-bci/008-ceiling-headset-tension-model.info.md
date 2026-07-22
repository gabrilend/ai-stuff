# 008-ceiling-headset-tension-model — info

> Black-box summary of the **ceiling-headset tension model**. Part of the
> experimental BCI branch (issue 207, Phase 2 stretch). DOCUMENTED, NOT SCHEDULED.

## What this module is

The hardware-real heart of the dream: an aim orientation becomes the four cable
tensions that would hold a ceiling-hung headset leaning that way "at just the right
tension." Pure geometry/statics — it moves nothing and reads no hardware; a real rig
would hand these numbers to servos (the deferred part). Cables in the lean
direction tighten; opposites ease; at rest all sit at the base tension.

## External functions

- `M.lean_from_aim(desc, aim) -> lx, ly`
  Reduces an aim (`yaw`, `pitch`) to a normalised lean in `[-1,1]²` (fraction of the
  neck's limits; `x` right, `y` up).

- `M.tensions(desc, aim) -> { cables = {north,south,east,west}, mean, any_clamped }`
  The one door. Each cable tension is `base + gain * dot(cable_dir, lean)`, clamped
  to the comfort band `[min_tension, max_tension]`. `mean` is the average of the
  four; `any_clamped` is true if an extreme lean hit the band edge.

- `M.format(result) -> string`
  A one-line human view (`N .. S .. E .. W .. (mean ..)`) for the demo/report.

## The invariant worth trusting

- Because opposing cables are symmetric, a lean that does **not** hit the comfort
  band leaves `mean == base_tension` exactly — the average tension stays at rest.
  That "average stays at the resting setpoint" is the concrete meaning of "just the
  right tension," and the demo (009) asserts it.
