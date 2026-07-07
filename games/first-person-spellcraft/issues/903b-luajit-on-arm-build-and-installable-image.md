# 903b — LuaJIT-on-ARM build & the installable Anbernic image/app

> **Phase:** 9 — Platform & Packaging · **Sub-issue of:** 903.
> **Role:** the second half of the pipeline — take the bundle manifest (from 903a)
> and make it run on the far machine. Cross-builds LuaJIT for the target ARM chip
> and folds the bundle into **one installable artifact** the device menu launches.
> **Blocked by:** 901 (arch / CPU class), 903a (the bundle manifest), 903 (the seam).

## Current Behavior

None of this exists yet. There is no build that targets anything but the
developer's own machine, no awareness of ARM, and no artifact a handheld could
install or a device menu could list. The bundle from 903a would have nowhere to go.

## Intended Behavior

A **cross-build driver** produces LuaJIT-on-ARM artifacts for the target chip named
in the hardware profile (901) — the developer's machine is *not* the target, so
this is genuinely a cross-build, and the LuaJIT-on-ARM considerations recorded
beside the profile in 901 are honored here rather than rediscovered. A **packager**
then folds the built code plus the bundle (903a) into a **single installable
image/app**: an app directory (or image) with the launcher, an icon, and whatever
metadata the Anbernic's menu needs to list and start it.

What the artifact must be:

- **Installable by copying** — dropped onto the device's SD card / storage and
  picked up by its menu; no store, no network, no account. (This is what makes the
  "give one copy to each european" distribution in issue 904 possible.)
- **Self-contained** — the target may not have a matching LuaJIT already; the
  artifact carries what it needs to run under the target's runtime.
- **Menu-legible** — the device's launcher understands its manifest/metadata and
  shows it with a name and icon.

Before the artifact is emitted, the **budget validator (901)** gates it: the
built footprint is measured against the memory/asset ceilings, and over-budget is
a loud, explained refusal — never a silent trim. A build that would not actually
run on the device must not be handed to anyone.

The honest unknowns (flagged, not hidden): exactly which Anbernic firmware/menu
conventions the artifact targets is model-dependent; 903b picks one concrete model
(the one profiled in 901) to build real, and notes what would differ for others.

## Suggested Implementation Steps

1. Read the LuaJIT-on-ARM considerations recorded in 901; confirm the target chip/
   arch from the profile.
2. Write the **cross-build driver**: produce LuaJIT-on-ARM artifacts for the target
   chip from the code in the bundle manifest.
3. Write the **packager / image builder**: fold built code + bundle + launcher +
   icon + metadata into one installable artifact the device menu understands.
4. Insert the **budget-validator gate (901)** immediately before emission; on
   over-budget, refuse with a spoken reason.
5. Verify the artifact installs by copy onto the target model and appears in its
   menu; if a physical device is absent, verify against the target model's runtime
   as far as possible and record exactly what remains unverified.
6. Record, in a comment beside the packager, which model conventions were assumed
   and what would change for a different Anbernic model.

## Stats / Meta

- **Kind:** cross-build + packaging (pipeline second half).
- **Cross-build:** dev machine ≠ target; LuaJIT targets ARM.
- **Gate:** budget validator (901) stands before artifact emission.

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  cross-build and package/image roles.
- Parent **903**; sibling **903a** (produces the manifest this consumes).
- Issue **901** — arch, budget gate, and the LuaJIT-on-ARM notes.
- Issue **904** — consumes this artifact for give-away distribution.
