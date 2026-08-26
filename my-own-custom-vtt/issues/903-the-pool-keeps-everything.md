# 903 -- The pool keeps everything

**Phase:** 9, the sprite studio
**Blocked by:** [902](902-the-paintbrush-is-a-closed-set.md)
**Blocks:** [904](904-two-ways-of-rating.md)
**Documents:** [the sprite studio](../docs/017-the-sprite-studio.md)

## Current behaviour

Sprites can be made. Nothing remembers them.

## Intended behaviour

Every sprite ever generated, kept.

### Nothing is ever deleted

Not the bad ones. **A low tier is information** — it records what missed and by
how much. Re-rating later can promote something mis-scored in a hurry. And a pool
you prune is a pool whose history cannot be reconstructed, which makes every later
question about why the output drifted unanswerable.

Storage is cheap. Judgment is expensive. **Never throw away the expensive thing to
save the cheap one.**

### What every entry holds

| Field | Why it is there |
| --- | --- |
| The sprite | The thing. |
| The description that produced it | With the seed, this regenerates it exactly. |
| The paintbrush and canvas it came from | Without these a rating means nothing later — you cannot tell whether a bad score was bad work or an impossible brief. |
| Category | Quality is always discussed per-category. |
| Tier | The five-step score. |
| Who set the tier, and when | A machine rating must never quietly masquerade as a person's. Also: the agreement measurement is computed from exactly this. |

### Five tiers, one scale

5 reach for it first · 4 use freely · 3 fine among others · 2 kept but not
reached for · 1 the record of what missed.

**One scale, used by people and machines alike.** That is what makes a floor work
and what makes agreement measurable.

### Categories

Quality is never discussed globally. Nobody says "the sprites are bad"; they say
*the goblins* are bad. The categories are the `kind` families a ruleset declares
— which makes them the ruleset's to name.

## Suggested implementation steps

1. A directory per pool, one file per sprite plus one index.
2. The index is text, so it diffs and a person can read it.
3. Append-only in spirit: a tier may be rewritten, an entry never removed.
4. Write the companion `.info.md`.
5. Test: an entry survives a reload; a re-rating replaces a tier without losing
   who set the previous one.
