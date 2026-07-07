# 606 — Per-stat difficulty tuning

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** 602 (capability estimate + yardstick), 603 (chosen modality),
604 (re-estimated values feed the estimate), 605b (learned-context discount).
**Blocks:** 607 (the lair generator consumes the difficulty target).

## Current Behavior

None of this exists yet. Even with a capability estimate (602), a chosen modality
(603), and a learned-context discount (605b) all available, nothing combines them
into an instruction the lair generator can act on. There is no "how hard should
this lair lean on each stat" object.

## Intended Behavior

The **integrator** that turns everything the DM believes into a single
**difficulty target**. Given a party-capability estimate, the current level
yardstick, a chosen challenge modality, and the learned-context discounts, it
produces — **per stat** — how hard this lair should press that stat, plus the
modality to build through and any easing from the library.

This is where the vision's "puzzles that would exactly suit the levels of the
characters" becomes real: the DM does not pick one global difficulty, it sets a
target **per stat**, so a party strong in one stat and weak in another gets a
lair that presses the weak stat (via the modality chosen in 603) while not
boring the strong one. Designed per-stat now even though multi-character parties
are a sequel feature — a lone NCP's stats are a party-of-one's stats.

Order of composition (documented so future readers know *why* each input
matters):

1. Start from the **capability estimate** — aim near the party's edge.
2. Read the target level through the **yardstick** — "near their edge" means more
   after they have conquered before.
3. Bias toward the **chosen modality's** leaned-on stats — press the intended way.
4. Subtract the **learned-context discount** on families they have studied — a
   well-read party earns easier puzzles where they did the reading.

Prefer erroring over silently clamping an out-of-range target; if a clamp is ever
needed it must announce itself (a fallback is a warning; warnings are errors).

## Suggested Implementation Steps

1. Define the **difficulty target** structure: per-stat pressure, chosen
   modality, and per-family easing.
2. Write the **tune** function composing the four inputs in the documented order.
3. Keep each composition step a small, named, separately testable helper, so the
   policy ("press the weakness," "reward the reading") can be adjusted in one
   place with a comment explaining the change.
4. Validate the target is well-formed and in range; error loudly otherwise.
5. Companion `*.info.md` describing the tune function and the target structure.
6. Tests: a strong-in-X, weak-in-Y party yields higher pressure on Y; a
   conquered-before party (stretched yardstick) yields a harder target than a
   fresh one at the same raw levels; a studied family yields a lower target than
   an unstudied one; the chosen modality's stats are pressed.

## Meta

- **The bridge issue.** Everything upstream is belief; everything downstream is
  construction. This is the one file that turns one into the other.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — stage B and
  the "difficulty target" structure.
- Issues 602, 603, 605b provide the inputs; issue 607 consumes the output.
