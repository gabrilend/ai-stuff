<!-- made by scripts/build-info-pages from the comments in 011-hit-resolution.lua; change the comments and rebuild, not this page -->
# 011-hit-resolution


What happens when a swing strikes. The steps run in one fixed order, and
each either ends the resolution or passes it on:

  reach -> parry -> flank -> critical -> damage -> effect

A volley's dart (013-ranged.lua) joins the same order at the parry step,
with its own parry bonus, so a thrown weapon and a sword obey one set of
rules about armor, criticals and falling.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.parry_roll` | `battle, t, bonus, from_x, from_y, stream` | Whether t turns the blow aside. Only a soldier standing, guarding, not open after an overhead, and not struck from behind may try. |
| `M.apply_damage` | `battle, t, damage, attacker` | The effect step, shared with volleys: health falls, the target reels, a windup in progress is lost, and at zero the soldier falls and frees its cell. |
| `M.armor_share` | `battle, t` | The share of damage armor lets through. |
| `STEPS.reach` | `battle, ctx` | The target must be alive, within reach, and in front of the attacker. |
| `STEPS.parry` | `battle, ctx` | A successful parry costs both soldiers stamina and staggers the attacker. A riposte answers it at once with a quick stab. |
| `STEPS.flank` | `battle, ctx` | (no comment in the source) |
| `STEPS.critical` | `battle, ctx` | The chance roll is always drawn, so the hits stream advances the same way whatever the other causes were. |
| `STEPS.damage` | `battle, ctx` | (no comment in the source) |
| `STEPS.effect` | `battle, ctx` | (no comment in the source) |
| `M.resolve` | `battle, a, swing` | Resolves a's swing on the tick it strikes. Returns the context, whose fields say how far it got (for tests). |

## Tables of rows

| Name | What it is |
| --- | --- |
| `STEPS` | The steps. Each takes the context and returns true to carry on. |
| `CAUSES` | The causes of a critical hit, in the order they are credited: the first that holds is the one the statistics count. |
| `ORDER` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `emit` | `battle, event` | (no comment in the source) |
| `off_facing` | `of, from_x, from_y` | How far, in radians, a point lies off a soldier's facing: 0 dead ahead, pi directly behind. |
