# 903 -- The pool keeps everything

**Phase:** 9, the sprite studio
**Blocked by:** [902](902-the-paintbrush-is-a-closed-set.md)
**Blocks:** [904](904-two-ways-of-rating.md)
**Documents:** [the sprite studio](../../docs/017-the-sprite-studio.md)

## Current behaviour

**Done.** `085-sprite-pool` keeps every sprite it is given and has no function
that removes one. Deletion is absent rather than guarded, which is the strongest
form the rule can take.

An entry holds the description that made it, the paintbrush and canvas it came
from, and both opinions of it.

### Two tiers are stored, one is effective

This is a deliberate departure from what this issue asked for. "Both write the
same field and the person's wins" works perfectly and destroys, on every
correction, exactly the data the agreement rate is computed from — and the
agreement rate is the entire reason for having a machine rate anything.

So the machine's tier and a person's live in separate fields, neither ever
overwrites the other, and the effective tier is the person's where there is one.
The behaviour is what the issue described; the storage is not.

### The paintbrush is a fingerprint, not a version number

Nobody remembers to bump a version. The fingerprint is computed: eight fixed
categories and seeds are drawn and encoded, and the bytes of the resulting files
are folded together. Anything that changes what a word turns into — a new shape,
a different body size, a change to the encoder — changes the number without
anybody noticing it needed to.

It is folded over the FILES rather than the structs, because a struct has padding
whose contents depend on the compiler, and a pool copied between two machines
would otherwise report every entry as stale.

### The index is text and a damaged line stops the read

Nine fields per line, separated by single spaces, with the header naming them. A
line the reader cannot understand ends the read and says which line — because a
reader that skipped it would be a pool quietly deleting an entry, silently, at
load, months after whatever damaged it.

A rater's name with a space in it is refused at the moment of rating rather than
escaped at every place that writes a line.

### Categories are a wall

Lowercase letters, digits and dashes. A category becomes a filename, and a
category with a slash in it names a file somewhere else entirely. Refused rather
than sanitised, because a sanitised category is a category somebody cannot find
again.

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
