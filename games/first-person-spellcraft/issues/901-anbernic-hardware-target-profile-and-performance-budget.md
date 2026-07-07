# 901 — Anbernic hardware target profile & performance budget

> **Phase:** 9 — Platform & Packaging
> **Role in phase:** the taproot. Every other Phase-9 issue reads the thing this
> issue produces (a measured description of the target machine) before it decides
> what to build, how to degrade input, or whether a build is allowed to ship.
> **Blocks:** 902, 903 (903a/903b), 904, 906.
> **Blocked by (within phase):** nothing.
> **Depends on (across phases):** conceptually all — a budget is only meaningful
> once there is a whole game to measure — but this issue can be *drafted* early,
> since its job is to describe the machine, not the game.

## Current Behavior

None of this exists yet. There is no description of the target hardware anywhere
in the project, no notion of a performance budget, and no tool that measures a
device. Any number about "how much RAM an Anbernic has" would today be a guess
typed into a doc, which the project forbids (hard numbers rot).

## Intended Behavior

The project can, on demand, produce an honest **target hardware profile** for a
given Anbernic model, and from it derive a **performance budget** that later
Phase-9 work checks builds against. Nothing about the device is hardcoded into
documentation; a **hardware probe** reads the real values (from the device, or
from a machine-readable spec record for a model not physically present), and a
**budget validator** consumes them.

Key properties the profile must capture, because later issues branch on them:

- **Architecture / CPU class** — it is ARM Linux, not the developer's machine;
  this is what makes the build a *cross*-build (issue 903b) and what LuaJIT must
  target.
- **Available RAM** — the ceiling the whole running game, most heavily the Phase-6
  local AI Dungeon Master, must fit under.
- **Screen** — small, fixed resolution; the Doom-style renderer's output target.
- **Input kind** — a **gamepad, and no mice.** This single fact is the reason
  issue 902 (input fallback) exists at all. The profile records how many sticks
  and which buttons the pad has, because that decides how far the dual-mouse aim
  can degrade before it loses a hand.

The **performance budget** derived from the profile is an envelope, not a score:
a frame-time ceiling (so the loop stays playable), a memory ceiling, and an
asset-size ceiling (so the artifact fits the device's storage). The budget is
*derived*, so when a new Anbernic model is profiled, its budget follows without
anyone editing prose.

The **budget validator** answers one yes/no question about a candidate build:
does it fit? A "no" is a **loud, explained error** ("over memory ceiling by X
because Y"), never a quiet trim of assets — per the no-silent-fallback rule.

Because Anbernic ships many models, the profile is **per model**, and the tools
handle "this model is not physically on my desk" by reading a stored spec record
rather than refusing to run.

## Suggested Implementation Steps

1. Define the **target hardware profile** structure — the fields above (arch, CPU
   class, RAM, screen, input kind + stick/button inventory), by role, in plain
   terms. Leave every value to be filled by measurement, not literal.
2. Write the **hardware probe** tool: on a real device it reads live values; for
   an absent model it reads a stored, machine-readable spec record. It fills a
   profile. It *measures, never assumes* — a missing value is an error naming the
   field, not a default.
3. Define the **performance budget** structure (frame-time, memory, asset-size
   ceilings) and the **derive-budget** function that turns a profile into one.
4. Write the **budget validator**: given a candidate build's measured footprint
   and a budget, return fit / no-fit with a spoken reason on failure.
5. Capture, as comments beside the profile structure, the LuaJIT-on-ARM
   considerations that other issues will lean on (why cross-building, why ARM
   matters), so 903b does not rediscover them.
6. Provide a small record for at least one concrete Anbernic model so 903/906 have
   something real to build and demo against; mark clearly that the numbers come
   from the probe/spec record, not from prose.

## Stats / Meta

- **Kind:** foundation / measurement.
- **Hardcoded numbers introduced:** none — that is the point.
- **Downstream readers:** 902 (input kind), 903a/903b (arch, asset-size), 904
  (artifact size for distribution), 906 (demo target).

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  probe → profile → budget → validator flow, and the "no hardcoded numbers" stance.
- [roadmap.md](../docs/roadmap.md) — Phase 9 depends on all prior phases; Phase 6
  is the heaviest budget tenant.
- [vision-overview.md](../docs/vision-overview.md) — target platforms; language
  policy (LuaJIT keeps the ARM door open).
- Tools introduced here: **hardware probe**, **budget validator**, **derive-budget**.
