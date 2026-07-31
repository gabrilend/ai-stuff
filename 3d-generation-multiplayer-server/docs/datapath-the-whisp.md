# datapath — the whisp

*a character id and a position → a pink star that squiggles → the only curve on
screen*

The visual thesis of the project, and the thing the person named before
anything else existed. `notes/spoken-while-building.md` holds the words it came
from; this document is how the words become vertices.

---

## The thesis, restated so the code can be checked against it

    world:  ▲ ■ ◣ ■        rigid · one of four schemes · straight edges only
            ■ ◤ ▲ ■

     you:      ✳ ~~~~,     pink · radial · wandering · always the exception

**The terrain is rigid and the inhabitants are not.** Every property of the
whisp exists to hold one side of that contrast:

| Property | Why it is that way |
|---|---|
| **pink** | appears in none of the four schemes, so nothing in the world can be confused for a living thing |
| **star** | radial, in a world made entirely of right angles; radial form reads as *light* rather than as architecture |
| **squiggle** | the only curve anywhere; hand-drawn wandering against machine-drawn edges |
| **trail** | motion is legible from its history, not just its position |

If a later decision makes the terrain curved, or makes a whisp square, or puts
pink in the environment, it has broken the thesis and needs to say so out loud.

---

## Where a whisp comes from

```
   SMSG_UPDATE_OBJECT ──▶ src/world/entities
                              │
                              │  guid, position, facing, velocity, name
                              ▼
                         src/draw/whisp
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
         the seed        the skeleton     the wander
      (from the guid)   (arms, radially)  (offsets, in time)
              └───────────────┼───────────────┘
                              ▼
                        vertices, per frame
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
              halo pass            core pass
         (scheme contrast)          (pink)
```

Nothing above the dotted line knows a whisp is pink. `src/world/` holds
positions and identities; `src/draw/whisp` is the only place that knows what a
character looks like, and it is a pure function of *(identity, position,
velocity, time)*.

---

## Identity comes free, from the id

Every character already has a unique 64-bit identifier that the server sends and
every client sees. **That identifier is the entire source of a whisp's
appearance.**

```c
    /* Why the guid and not a server field: appearance costs zero bytes of
       protocol this way, and every client independently computes the same
       whisp for the same character. Adding a "looks like" field to the wire
       would mean patching the server, versioning the field, and handling the
       case where it has not arrived yet. A hash of something everyone already
       has has none of those problems. */
    seed = mix64(guid);
```

From that seed: the arm count, the base phase of each arm's wander, the wander
frequencies, the spin direction, and the secondary hue. The consequences are
worth being explicit about, because this is the kind of decision that quietly
pays for years:

- **Your whisp is yours.** Stable across sessions, servers, and reinstalls.
- **Everyone sees the same one.** No synchronisation, because there is nothing
  to synchronise — the function is deterministic and the input is public.
- **It costs nothing.** Not one byte on the wire, not one row in a database.
- **It survives the narrowing.** When phase 5 deletes most of the character
  system, appearance is not among the casualties, because it was never stored.

The mixing function must be a real avalanche mix, not a truncation. Sequential
identifiers are common — characters made in a row on a fresh server differ only
in the low bits — and a weak mix would give a whole guild nearly identical
whisps.

---

## The skeleton: a star

Arms radiate from a centre. Each arm is a polyline of a handful of points
marching outward.

```
                      ·
                   ·                      arm a, point i:
                ·
             ·                              θ = 2π·a/arms  +  spin·t
    ·  ·  ·  ●  ·  ·  ·                     r = (i / points) · length
             ·   ╲                          p = centre + (cos θ, sin θ)·r
                ·  ╲
                   ·                      before the wander is added
                      ·
```

The arm count comes from the seed, in a small range — enough that two whisps
side by side are visibly different, few enough that every one still reads as a
star rather than as a blob. The current range and every other tunable number
lives in `src/draw/whisp` and is recorded, with its reasons, in
`docs/balance-updates.md` — not frozen into this document, where it would go
stale the first time somebody turned a knob.

The star **billboards**: the plane it is drawn in always faces the camera. A
star with a back face is a star that occasionally disappears, and a floating
whisp has no meaningful orientation to preserve. This is the one place the
project accepts a not-quite-3D object in a 3D world, and it is accepted because
the alternative is a player who cannot find themselves.

---

## The wander: what makes it squiggle

Each point is pushed **perpendicular** to its own arm by a sum of sine waves.

```
    offset(a, i, t) =  amplitude(i) · Σ  A_k · sin( ω_k·t  +  φ_{a,k}  +  λ_k·i )
                                      k
```

Three components, three jobs:

- **`ω_k` — the frequencies.** Deliberately not multiples of one another, so the
  sum never repeats on any short cycle. A whisp that visibly loops stops looking
  alive; incommensurate frequencies mean the pattern does not close.
- **`φ_{a,k}` — per-arm phase, from the seed.** Arms wander independently. Give
  them a shared phase and the star pulses like a jellyfish instead of drifting.
- **`λ_k·i` — the phase marching outward along the arm.** This is what turns a
  rigid waving arm into a travelling ripple. Without it each arm is a straight
  segment that swings; with it the arm itself curves.

And the amplitude **grows with distance from the centre**:

```
    amplitude(i)  ∝  (i / points)²
```

The root of each arm barely moves; the tip wanders freely. This single choice is
most of why the shape reads as *soft* rather than as *broken*: the centre stays
a coherent, findable point — which is what a player actually tracks — while the
silhouette never holds still.

Motion deforms the star as well. Velocity from the movement block stretches the
whisp along its direction of travel and compresses it across, so a moving whisp
is legibly moving even in a still frame.

---

## The trail

A ring buffer of world positions, sampled on a fixed interval rather than per
frame — so the trail's shape is the same on a slow machine and a fast one, which
matters because it is a gameplay-legible signal about where somebody went.

```
    positions:  [ p₀  p₁  p₂  …  pₙ ]   oldest ──────────▶ newest
    width:        ·   ·   ∙   ●   ⬤     tapers toward the past
    alpha:       0.0 ─────────────▶ 1.0
```

Drawn as a tapering strip: each sample expands to two vertices offset
perpendicular to the local direction of travel, width and opacity falling off
toward the oldest end. Standing still, the buffer collapses and the trail
vanishes on its own with no special case — which is the correct behaviour and
also the cheapest one.

---

## The colour, in four worlds

Pink has to survive four different backgrounds. The naive approach — one RGB
triple — fails immediately: a pink that sings against black is washed out
against white, and a pink dark enough for white looks muddy against black.

So the whisp is defined in **hue-first terms** and resolved per scheme:

| Scheme | Background | World colours | The whisp's pink |
|---|---|---|---|
| white | bright | bright | deepened and saturated, so it does not glare out |
| black | bright | bright | luminous, near its brightest form |
| blue | muted | muted | the only saturated thing in frame — maximum contrast |
| green | muted | muted | pushed toward magenta, away from green's neighbours |

The hue stays pink in all four. Only lightness and saturation move, and they
move by rule rather than by four hand-picked triples — the rule is "hold a
minimum perceptual contrast against this scheme's background," which is checkable
by a small tool rather than by eye.

**Two passes guarantee it.** A wider **halo** in the scheme's contrast colour is
drawn first, then the **core** in pink on top. On white the halo is dark, on
black it is light. A whisp is therefore never lost against terrain that happens
to sit near its own colour — the outline does the work that colour alone cannot.

> **An open question, honestly unresolved.** The vision says characters are
> *multicolour* whisps; the person said *pink*. The proposal on the table: pink
> is the constant — the shared form, the species — and per-character variation
> lives in a secondary hue at the **arm tips**, derived from the same seed. So
> every whisp is unmistakably a pink star squiggle, and no two are the same one.
> Recorded in `docs/roadmap.md` and not decided here.

---

## Cost, and why it does not matter much

Per whisp, per frame: arms × points positions, each costing a handful of sine
evaluations, plus the trail. The counts are small and the arithmetic is flat —
no branches, no memory chasing, contiguous output. It vectorises trivially and
is a natural candidate for the "can this part be assembly?" question, which is a
better reason to try it than performance would be.

The real budget question is how many whisps are on screen at once, and the
honest answer is that we do not know until people are playing. The generation
loop is written to fill a pre-allocated vertex buffer, walking it in order, so
the work can be split across threads by handing each one a slice of the buffer
if it ever needs to be.

---

## Where this lands in the code

```
src/draw/
    whisp       seed → arms → wander → vertices. Pure; no GL calls.
    trail       the ring buffer and its tapering strip
    palette     the four schemes, and the contrast rule
    billboard   camera-facing plane construction
```

`whisp` produces vertices and never issues a draw call, which means its output
can be dumped to a file and rendered as a still image by a test — a squiggle is
exactly the kind of thing that is easier to check by looking at it than by
asserting on numbers.

## Related

- `notes/spoken-while-building.md` — the three words this is built from
- `docs/datapath-the-world-of-shapes.md` — the rigid half of the contrast
- `docs/datapath-the-world-stream.md` — where position and identity arrive from
- `docs/balance-updates.md` — every number in here, and why it was last turned
