# Datapath — Dual-Mouse Aiming & Input (Phase 2)

> The data-flow map for the signature two-mouse "boomstick" peripheral. This
> traces one packet of intent from the moment a mouse twitches on the desk to the
> moment a spell knows where it is aimed. It lists the structures and functions by
> the ROLE they play, not by their eventual code names — the code names are the
> issue files' job.
>
> Back to the index: [table-of-contents.md](table-of-contents.md). Phase plan:
> [roadmap.md](roadmap.md). The vision this serves:
> [vision-overview.md](vision-overview.md) (§ Phase 2) and
> [notes/vision](../notes/vision) lines ~1-13 (two mice, two hands, hand
> animation, the BCI stretch) and ~112-114 (aiming while playing as an NCP).

---

## The one-sentence shape

Two physical mice, read as **distinct devices**, become two animated hands
gripping a wand; the geometry of the two grips is an aim direction; that aim is
laundered into a **source-agnostic aim state** that spells, the renderer, and
the NCP AI all read without ever knowing a mouse existed.

---

## The pipeline, stage by stage

```
  physical desk                                          the rest of the game
 ┌──────────────┐                                       ┌────────────────────┐
 │  mouse L     │                                       │  Phase 1 renderer  │  hand poses
 │  mouse R     │                                       │  Phase 3 spells    │  aim + trigger
 └──────┬───────┘                                       │  Phase 5 NCP AI    │  (as a SOURCE)
        │                                               └─────────▲──────────┘
        v                                                         │
 [1] raw evdev event stream   (two /dev/input/eventX nodes)       │
        │   struct input_event records, one per axis/button       │
        v                                                         │
 [2] per-device event drain   (once per game tick, non-blocking)  │
        │   deltas + button edges, framed on SYN_REPORT           │
        v                                                         │
 [3] per-hand state           (left-hand, right-hand)             │
        │   accumulated motion, button state, per-device calib    │
        v                                                         │
 [4] dual-grip aim geometry   (two grip poses -> one orientation) │
        │   barrel line + twist -> aim direction, roll            │
        v                                                         │
 [5] canonical AIM STATE  ────────────────────────────────────────┘
        (orientation + discrete intents + per-hand pose channel + source tag)
        ▲
        │  same struct, produced by OTHER sources:
        ├── gamepad / single stick   (Phase 9, Anbernic — no two mice)
        ├── AI aim source            (Phase 5, autonomous NCP)
        └── BCI + ceiling headset    (Phase 2 STRETCH, deferred)
```

The stages map onto the issue files: [1]-[2] are issues 201a/201b, [3] is 202 (+
203 calibration), [4] is 204, hand animation off [3]/[4] is 205, and the
canonical aim state plus the source registry is the capstone, 206. The stretch
source is 207.

---

## Stage-by-stage data description

### [1] Raw evdev event stream — the hard technical core
- **Why it is hard:** the OS normally *merges* every mouse into one shared
  cursor. To read two mice as two independent inputs we bypass the merged cursor
  and read each device's own node directly.
- **Data in:** the kernel writes fixed-size binary records to `/dev/input/eventX`.
  On 64-bit Linux each record is a `struct input_event` (a timestamp, then a
  16-bit `type`, a 16-bit `code`, a 32-bit `value`). Record size and field layout
  are a hard format fact and belong as a comment at the read site.
- **Event kinds we care about:** relative-motion events (`EV_REL` with codes for
  X, Y, wheel), button events (`EV_KEY` with the mouse-button codes), and the
  frame terminator (`EV_SYN` / `SYN_REPORT`) that says "this batch of deltas is
  one coherent movement, apply it together."
- **Structures by role:** a *device handle* (open file descriptor + identity),
  and a decoded *event record view* over the raw bytes (LuaJIT FFI cast, no copy).

### [2] Per-device event drain
- **Cadence:** called once per game tick by the Phase 1 loop's input hook. Reads
  are **non-blocking** — drain whatever is queued, stop when empty, never wait.
- **Data out:** for each device this tick, a summed motion delta (x, y, wheel)
  and a set of button edge changes (pressed-this-tick / released-this-tick),
  closed off at `SYN_REPORT` boundaries.
- **Structure by role:** a *per-device tick accumulator* that is zeroed at the
  start of each drain and filled as records are consumed.

### [3] Per-hand state
- **Role assignment:** exactly one device is the **left hand**, one is the
  **right hand**. Which physical mouse is which hand is an explicit, persisted
  mapping — never guessed silently. (Guessing would be a fallback; a fallback is a
  warning and a warning is an error. If the mapping is unknown, ask, don't assume.)
- **Data held per hand:** accumulated grip position/orientation on that hand's
  input surface, current button state, and the source of truth the geometry reads.
- **Calibration seam (203):** the raw per-device delta passes through a
  per-device sensitivity curve, dead-zone, axis inversion, and a re-center offset
  *before* it lands in the hand state. Each mouse is calibrated independently, so
  a heavy left mouse and a twitchy right mouse feel matched.
- **Structures by role:** two *hand state* records (left, right); two *device
  calibration profiles*.

### [4] Dual-grip aim geometry
- **The model:** think of a rifle or a wand held at two points. The two hands are
  two grip points in the player's local aim space. The **aim direction** is the
  normalized vector along the "barrel" the two grips define (rear grip → front
  grip). The **roll / twist** of the wand comes from the relative offset between
  the hands (raising one hand rolls the boomstick). One primary combining rule is
  chosen in issue 204; an alternate "base + brace" differential model is noted
  there as the second option.
- **Data in:** two hand states. **Data out:** an *aim result* — a direction (yaw
  + pitch, or a unit vector / quaternion) plus a roll angle, expressed in
  player-local space so it survives the player turning.
- **Structure by role:** a pure *combine grips → aim* function; it holds no state,
  so it is trivially testable with hand-authored grip inputs.

### [5] Canonical aim state — the source-agnostic seam (the load-bearing deliverable)
- **Why it exists:** everything downstream must aim without caring HOW the aim was
  produced. Dual-mouse is the first producer; a gamepad, an AI, and the BCI are
  later producers of the *same* struct.
- **What the aim state carries:**
  1. **Aim orientation** — the primary direction (and roll) a spell fires along.
  2. **Discrete intents** — normalized signals like fire / begin-charge /
     release / alt, decoupled from any specific button so a gamepad or AI can
     raise them too.
  3. **Per-hand pose channel** — optional two-hand pose data for the renderer.
     Dual-mouse fills it from real grips; sources without two hands (gamepad, AI)
     fill it with a synthesized/idle pose so the hands still animate.
  4. **Source tag** — which source produced this frame (for HUD + debugging).
- **The source interface (contract every producer implements):** advance-one-tick
  (produce the current aim state), activate / deactivate (acquire and *release*
  its devices — releasing matters so switching sources doesn't leave a mouse
  grabbed), and a small identity/capability descriptor (does it provide real
  per-hand poses? real buttons?).
- **The active-source registry/selector:** holds every registered source, tracks
  the one active source, routes the loop's per-tick update to it, and publishes
  the resulting aim state to consumers. Runtime switching is a first-class
  operation: desktop dual-mouse ↔ gamepad ↔ AI takeover.

---

## Where other phases plug in (the seams)

- **Phase 1 — Engine Foundation** ([datapath-engine-foundation.md](datapath-engine-foundation.md)):
  provides the game loop's **input hook** that calls the active source's
  advance-one-tick each frame, and the **renderer** that reads the per-hand pose
  channel to draw the two hands on the boomstick. Phase 2 does not own the loop;
  it registers into it.
- **Phase 3 — Spell System** ([datapath-spell-system.md](datapath-spell-system.md)):
  reads the aim state's **orientation** (where the spell goes) and **discrete
  intents** (fire / charge / release). It never touches a device.
- **Phase 5 — NCP Characters** ([datapath-ncp-characters.md](datapath-ncp-characters.md)):
  an **AI aim source** implements the same source interface. The registry swaps it
  in when an NCP is autonomous and swaps dual-mouse back in when the player takes
  the NCP over to aim by hand (vision ~112-114).
- **Phase 9 — Platform & Packaging** ([datapath-platform-packaging.md](datapath-platform-packaging.md)):
  the Anbernic handheld has **no two mice**. A gamepad/single-stick source
  implements the same interface, so no downstream code changes to run there.
- **STRETCH — BCI + ceiling headset:** a deferred source (issue 207) that reads
  "look up-and-to-the-left" attention patterns and moves a ceiling-mounted headset
  at the right tension. It plugs into the exact same source interface; documented,
  not scheduled.

---

## Testability notes (so the seams stay honest)

- Stages [3] and [4] are pure/near-pure: hand-author grip inputs, assert the aim
  direction. No hardware needed for the geometry tests.
- Stage [1]-[2] can be exercised against a **recorded event trace** (a captured
  stream of `input_event` records replayed from a file) so the read loop is
  testable without a physical second mouse plugged in.
- The source interface (206) is validated with a **fake source** that emits a
  scripted aim state, proving the registry and downstream read path work before
  any real device is involved.

---

## Related documents

- [vision-overview.md](vision-overview.md) — Phase 2 feature list and the
  sacrosanct BCI stretch quote.
- [roadmap.md](roadmap.md) — where Phase 2 sits in the dependency graph
  (needs Phase 1; feeds Phases 3, 5, 9).
- Issue files implementing this datapath: 201a, 201b, 202, 203, 204, 205, 206,
  and stretch 207 (in `issues/`).
