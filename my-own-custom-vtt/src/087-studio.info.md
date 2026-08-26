# 087-studio

Watching the watcher, and quoting the price before the sale.

Nothing in this file changes the pool. Every function reads and reports, which is
the correct shape for a set of measurements: a measurement that can alter what it
measures is not a measurement.

## The loop with no anchor

A system improved by a grader that is itself being tuned has nothing holding it
in place.

Let a person's ratings become rare relative to the machine's, and the whole
apparatus converges smoothly on **the grader's** taste rather than yours. No error
is raised anywhere. Nothing fails. You find out months later by not liking the
output, at which point every rating in the pool is suspect and there is no way to
tell which ones.

## Zero out of zero is not perfect

The single most dangerous number this project could print is a hundred per cent
agreement with a person who has never rated anything. Nothing disagreed. Nothing
agreed either.

| `standing` | When | Why it is its own state |
| --- | --- | --- |
| `AGREEMENT_UNMEASURABLE` | no entry carries both opinions | Silence is not consensus. |
| `AGREEMENT_THIN` | fewer than 20 pairs | Three out of three is a hundred per cent and swings thirty points on the fourth. |
| `AGREEMENT_MEASURED` | 20 or more | A number worth deciding on. |

**Read `standing` before the percentages.** That is the contract, not advice —
the rates are zero in the unmeasurable case, and printing "0.0% agreement" for a
pool nobody has rated is a different falsehood and no better.

## Which way it leans

`machine_bias_in_tenths` is the machine's tier minus the person's, summed and
averaged, in tenths of a tier. Positive means the machine is the more generous.

Worth having separately from the agreement rate because they answer different
questions. The rate says how often the machine is wrong; this says **which way**
— and a grader that is consistently one tier generous can be corrected rather
than replaced.

## The anchor

`studio_anchor` gives the human-rated fraction against a floor of five per cent
and says plainly when it is below.

An empty pool is **not** below the floor. There is nothing to have looked at, and
complaining at somebody who has not started yet is the studio nagging.

## The dial quotes its price

`studio_dial_report` compares two floors and applies neither. The answer arrives
while the question is still open, which is the whole point.

`studio_dial_sentence` writes it out:

> *goblin: raising the floor from 3 to 4 leaves 31 to draw from instead of 214,
> out of 400 in the category — expect them to start resembling each other.*

The consequence comes from a table of how much of the pool survives, so the
thresholds sit together where they can be argued with rather than being spread
through a chain of comparisons:

| Survives | Reads as |
| --- | --- |
| 80% or more | barely any variety is lost |
| 50% | expect some repetition |
| 25% | expect them to start resembling each other |
| 8% | expect to see the same few over and over |
| below that | there will be almost nothing to choose from |

Lowering a floor says the opposite thing rather than announcing a cost, because
variety is being bought back rather than spent.

This is the same axis that decides whether a trained system memorises or wanders,
pulled out of the internals and put where a person can reach it.

## Two dials, not one

`TRUST_ANYBODY` and `TRUST_A_PERSON` are different requests. "Tier 4 or better"
and "tier 4 or better *as judged by a person*" — the second is smaller and more
trustworthy. Confidence and quality are not the same axis, and collapsing them
loses the distinction exactly when it matters.

## A studio that nags is a studio nobody opens

`studio_offer_sentence` carries its own cost: how many are unrated by a person,
and what rating them would buy. A question with no price on it has no honest
answer.

`studio_decline` records the refusal and touches nothing about the library. "Not
now" costs nothing and is not asked again, per category — turning down the
goblins is not turning down everything.

## Quality is never discussed globally

Every function takes a category. Nobody says the sprites are bad; they say *the
goblins* are bad. `EVERY_CATEGORY` is a named constant for the whole-pool case,
because `""` appearing in a call is a mistake and a name is a decision.

## Functions

| Function | Takes | Gives |
| --- | --- | --- |
| `studio_init` | a studio | nothing |
| `studio_agreement` | pool, category, a struct to fill | nothing; read `standing` first |
| `studio_agreement_sentence` | an agreement, a buffer | the buffer |
| `studio_anchor` | pool, category, a struct to fill | nothing |
| `studio_anchor_sentence` | an anchor, a buffer | the buffer |
| `studio_dial_report` | pool, category, two floors, a trust | nothing; applies neither floor |
| `studio_dial_sentence` | a report, a buffer | the buffer |
| `studio_may_offer` / `studio_decline` | studio, category | whether to ask / records a no |
| `studio_offer_sentence` | pool, category, a buffer | the buffer |
| `studio_summarise` | pool, category, a file | prints tiers, provenance, the honesty, agreement, and the anchor |

`studio_summarise` prints the sentence *the machine's tiers are a heuristic*
every time, not in a footnote. The tier numbers look like measurements and most
of them are a heuristic's guess, and a reader who does not know that is reading
the wrong thing.

## Related

- [085-sprite-pool](085-sprite-pool.info.md) — where the opinions live
- [082-sprite](082-sprite.info.md) — the heuristic itself
- [088-test-studio](088-test-studio.c)
- issues [906](../issues/completed/906-the-quality-dial.md),
  [907](../issues/completed/907-the-anchor-that-stops-drift.md)
