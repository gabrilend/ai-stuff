# 085-sprite-pool

Every sprite ever made, kept, and what anybody thought of it.

## Nothing is ever deleted

There is no function here that removes an entry. Deletion is **absent** rather
than guarded, which is the strongest form the rule can take.

- A low tier is information. It records what missed and by how much, which is the
  only evidence anybody has for whether the generator is getting better.
- Re-rating later can promote something scored in a hurry, and a pruned pool has
  thrown away the thing it would have promoted.
- A pool you prune is a pool whose history cannot be reconstructed, which makes
  every later question about why the output drifted unanswerable.

Storage is cheap. Judgment is expensive. Never throw away the expensive thing to
save the cheap one.

## Two tiers are stored, one is effective

| Stored | Written by | Never touched by |
| --- | --- | --- |
| `machine_tier` + `machine_when` | `pool_rate_by_machine` | a person's rating |
| `person_tier` + `person_when` + `person_name` | `pool_rate_by_person` | the machine's rating |

`pool_tier` returns the person's where there is one and the machine's otherwise.
`pool_tier_provenance` says which.

The behaviour is "both write the same field and the person's wins". The storage
is deliberately not. One field would work perfectly and would destroy, on every
correction, exactly the data the agreement rate is computed from — and the
agreement rate is the entire reason for having a machine rate anything. A grader
nobody has measured is not a grader, it is a rumour.

## The pool never reads a clock

Every rating's time is supplied by the caller. A session's time is its beat
number; a person at a terminal has a wall clock. A store that reached for one of
them would make the other one lie, and it makes every test exactly reproducible.

## What an entry holds

| Field | Why it is there |
| --- | --- |
| `category` + `seed` | The description. With these the picture regenerates exactly, which is why the pool stores forty bytes rather than a hundred. |
| `paintbrush` | Which generator drew it. Without this you cannot tell "badly drawn" from "drawn by a tool that no longer exists". |
| `canvas` | Which square it was drawn for. A rating of a picture drawn for a different canvas is a rating of a different picture. |
| `machine_tier`, `machine_when` | The heuristic's opinion, and when. |
| `person_tier`, `person_when`, `person_name` | A person's opinion, and whose. |

The paintbrush is a **fingerprint**, computed by
[`sprite_paintbrush_fingerprint`](082-sprite.info.md), not a version number
somebody remembers to bump.

## The two algorithms

| | `POOL_RATE_ON_ARRIVAL` | `POOL_JUDGE_THEN_CURATE` |
| --- | --- | --- |
| On arrival | the machine rates it | nothing |
| Later | a person rates a little, whenever | a person rates everything, once, then re-tiers during play |
| Shape | large pool, thin judgment, measured | small pool, complete judgment, contextual |
| Agreement rate | free and continuous | none — nothing to compare |
| Drift failure | real; see [087-studio](087-studio.info.md) | none, because every rating is a person's |
| Bounded by | storage | one person's patience |

The setting lives in the pool and travels with the file, so it belongs to the
library rather than to whichever program opened it.

Neither is the better one. A is for ten thousand generated dandelions; B is for
the forty things that actually appear in your campaign.

## The index is text and a damaged line stops the read

Nine fields per line, single spaces, with the header naming them. A line the
reader cannot understand ends the read and says which line — because a reader
that skipped it would be a pool quietly deleting an entry, silently, at load,
months after whatever damaged it. That is the one thing this whole module exists
to prevent.

A rater's name containing a space is refused at the moment of rating rather than
escaped at every place that writes a line. One refusal instead of an escaping
rule everywhere.

## Categories are a wall, not a preference

Lowercase letters, digits and dashes; not empty; no longer than 31. A category
becomes a filename, and a category with a slash in it names a file somewhere
else entirely.

Refused rather than sanitised. A sanitised category is a category somebody cannot
find again.

## Functions

| Function | Takes | Gives |
| --- | --- | --- |
| `pool_init` | a pool, an algorithm | 1, or 0 if memory could not be found |
| `pool_release` | a pool | nothing |
| `pool_add` | category, seed, when | the entry; the SAME entry if that description is already held |
| `pool_category_is_sound` | a word | 1 when a pool could hold it |
| `pool_rate_by_machine` | entry, when | 1, or 0 for an entry that is not there |
| `pool_rate_by_person` | entry, tier, who, when | 1, or 0 — a refused rating never looks like a recorded one |
| `pool_tier` / `pool_tier_provenance` | entry | the effective tier / who set it |
| `pool_count` / `pool_at` / `pool_find` | — / entry / category+seed | how many / the record / the entry |
| `pool_sprite` | entry, a sprite to fill | 1, and the CURRENT picture for that description |
| `pool_survivors` | category, floor, trust, an array, its size | how many survive — the true count, even when the array could not hold them |
| `pool_in_category` | category | how many, rated or not |
| `pool_from_another_paintbrush` | — | how many were drawn by a different generator than the one in use |
| `pool_write` / `pool_read` | a directory, a place for the reason | 1, or 0 with a sentence naming the file |

`pool_sprite` returns the current picture rather than the one that was rated, on
purpose: somebody looking at the pool today wants to see what that description
draws today. Whether it is the picture that was rated is a **separate** question,
answered by comparing the entry's fingerprint with the pool's — and conflating
the two would leave a caller unable to ask either.

## Related

- [082-sprite](082-sprite.info.md) — what an entry is a description of
- [087-studio](087-studio.info.md) — what is done with the opinions
- [086-test-sprite-pool](086-test-sprite-pool.c)
- issues [903](../issues/completed/903-the-pool-keeps-everything.md),
  [904](../issues/completed/904-two-ways-of-rating.md)
