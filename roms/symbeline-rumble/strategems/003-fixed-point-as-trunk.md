# 003 — Fixed-point as trunk

**Shape.** When a project must run on a constrained target and a
generous one, let the constrained target's numeric format become the
*canonical* format on both. The generous target adapts to the
constrained, not the other way around.

**Origin in this project.** The DS has no FPU; the trunk's gameplay math
is fixed-point; the native build also uses fixed-point for parity. See
`docs/008-fixed-point-math.md`.

**Where else it fits.**

- Embedded + cloud: the embedded build's serialization format becomes
  the canonical wire format; the cloud reads/writes it natively.
- Old browser + modern browser: the old browser's polyfill set becomes
  the API the codebase uses; modern browsers see the same API.
- Single-threaded + multi-threaded: if a feature must run on a single
  thread anywhere, write it as if everywhere is single-threaded; the
  multi-threaded host can layer parallelism on top.

**Why it works.** It eliminates the case where the generous target
silently gains features the constrained target cannot reproduce. The
constraint is *visible in the trunk* every day, instead of being an
afterthought during the port.

**Where it breaks.** When the constraint is so severe that the trunk
becomes unusable on the generous target (e.g., 32 KB total RAM in
embedded vs. a desktop app). At that point the trunk needs to be the
*data*, not the *runtime*, and the two runtimes share a serialization
format.
