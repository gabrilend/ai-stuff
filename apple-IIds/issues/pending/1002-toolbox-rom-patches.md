---
name: specific Toolbox ROM patches
phase: 10
status: pending
blockedBy: [1001]
---

# 1002 — specific Toolbox ROM patches

Apply specific ROM patches for things that source-level GS/OS
modification cannot reach. The specific patches are TBD based on
what phases 7/8/9 reveal as blocking.

## current behavior

The Toolbox ROM is unmodified.

## intended behavior

- Each ROM patch lives as `patches/NNN-name.tbox` per issue 1001's
  format.
- Each patch is **narrowly scoped** — fix one specific problem
  that source-level work could not. ROM patches are expensive
  (disassembly + binary-level changes); reserve them for what
  truly needs them.
- Candidate patches (concrete examples; actual list depends on
  what blocks the source-level work):
  - **Window Manager: drag clipping.** When the Finder's window-
    drag XOR feedback crosses certain regions, the ROM does
    something we don't want for our compositor-based overlay.
    Patch to omit the XOR feedback for a configurable region.
  - **Menu Manager: menu-bar dimensions.** The ROM hardcodes the
    menu-bar height. To match our overlay-aware status strip on
    each panel, this may need patching.
  - **QuickDraw II: blit ordering for the overlay plane.**
    Avoiding cosmetic conflicts between QuickDraw and the
    broker's overlay compositor may need a patch.
- Each patch is **paired with documentation**: the disassembly of
  the original routine, the modification, and the rationale.
  Future readers (including future-us) need to understand why a
  ROM patch was applied and what would happen without it.

## suggested implementation steps

1. Wait for phases 7/8/9 to reveal which ROM-resident behaviors
   block our work.
2. For each blocker, attempt a source-level workaround first.
   ROM patches are last-resort.
3. If no workaround works, disassemble the relevant ROM routine.
   Read it carefully.
4. Design the minimal patch (smallest byte change that achieves
   the goal).
5. Write the patch in the `.tbox` format with full documentation.
6. Test extensively — ROM patches affect every IIds program.

## related documents

- `issues/1001-toolbox-disassembly-infra.md` — the infrastructure
- `docs/001-architecture-overview.md` — Toolbox ROM as a
  modification surface, used narrowly

## known design questions

- How many ROM patches are likely? Hopefully zero or one. The
  source-level surface covers most of GS/OS; the ROM is mostly
  the Toolbox managers, and most of *those* can be wrapped
  rather than patched.
- What's the policy on ROM patches and bare-metal? After phase 11,
  the Toolbox is being rewritten in ARM assembly anyway. ROM
  patches are a staging-ground concept; in the bare-metal era
  they translate to "we rewrote that routine differently."

## notes

- This issue is intentionally vague. Phase 10's concrete content
  emerges from phases 7/8/9's experience. Write the specific
  sub-issues as they're identified.
