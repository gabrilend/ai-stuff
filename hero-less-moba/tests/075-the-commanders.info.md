# 075-the-commanders

The commanders, their heroes and what the heroes do, asked of a world that has barely ticked.

## Running it

```
luajit tests/075-the-commanders.lua
```

Exits non-zero if anything failed. `./run-tests` runs it in the running half, after
the invariants and the formation sandbox.

Every check builds a fresh match with the bots switched off, then puts bodies exactly
where its question needs them. Only the wave check lets the match run, and only long
enough for the first waves to walk out. The run's own count is the answer to "how
many are there".

What [051](051-the-invariants.info.md) already asks of commanders is not asked
again: that killing pays the whole team (502), that a hero is a soldier you bought
(503), and that a hero obeys one sign-post (508).

## What it checks, grouped by issue

### 501 — the catalogue, and how it is dealt

| Check | Fails the day somebody… |
| --- | --- |
| Every commander has a name, a wave captain and at least three priced heroes | …adds a commander with a roster row that is not a hero, or a hero with no price. |
| **The two teams are dealt the same hand, seat for seat** | …deals across all six seats again, which gave one team two paladins and the other two nobles. |
| Every wallet starts empty, at the first rung's ceiling | …starts a match with somebody already able to buy. |
| A team's waves are sent by each of its players in turn | …breaks the rotation that makes commander choice a team conversation. |
| A body's bounty colour walks the commander's ratio exactly, and repeats | …samples the ratio, so an opponent can no longer learn it by watching. |

### 504 — abilities are a dispatch table

| Check | Fails the day somebody… |
| --- | --- |
| Every ability a hero names has a condition, an effect and a cooldown | …misspells a row, which would otherwise surface only when that hero is first bought. |
| A priest beside a wounded ally mends it by the ability's power | …breaks the run loop or the heal effect. |
| **The ability event says which ability it was** | …puts the ability's name back in `name`, where `raise` overwrites it with "ability". |
| Its cooldown is the ability's, and it does not fire again next tick | …lets a hero cast every tick. |
| A heal never lifts a body past its maximum | …lets overheal in, which flattens "whose gap does this fit" into "who is worst off". |
| An ability missing from the table is an error that names it | …turns the error into a hero quietly doing nothing. |

### 505 — onto a wave

| Check | Fails the day somebody… |
| --- | --- |
| A hero bought onto a living wave arrives in its lane, at its front | …breaks wave placement. The issue intends the rearmost living member; what is built is the front, and this pins what is built. |
| **It does not join the wave's record** | …counts a hero toward `member_count` or `living_count`, so feeding heroes keeps a wave from being wiped. |
| The enemy's wave, and an empty one, are refused as gone | …lets a hero be bought onto a wave that is not yours or has nobody left. |

### 506 — onto a tower

| Check | Fails the day somebody… |
| --- | --- |
| A clear tower of your own accepts a hero, which stands at it | …breaks tower placement. |
| An enemy inside its radius refuses it, charging nothing and spawning nothing | …turns the refusal into a silent redirect, or charges for a refused purchase. |
| **The refusal names the nearest tower behind, not the furthest** | …picks the smallest milestone again, which named the tower beside the library whenever any tower between was clear. |
| With every tower in the lane under attack, the refusal names the library | …leaves the player with nowhere named. |
| The enemy's tower, a fallen one, and a destination that does not exist are refused | …loosens who may spawn where. |

### 507 — at the library

| Check | Fails the day somebody… |
| --- | --- |
| A library hero enters the lane pushed deepest into, by milestone | …measures pressure by distance instead. |
| A tie goes to the lower lane number | …breaks ties with a random stream, so a player cannot predict where their hero goes. |
| Team 2's hero enters at its own end of the lane | …mirrors the entry point wrongly for the far team. |

### 509 — the rosters

| Check | Fails the day somebody… |
| --- | --- |
| Every roster is five different heroes with no ability in common | …builds a roster as one soldier at three grades. |
| Somebody can kill a line, somebody can kill stone, somebody can mend | …drops a job the game needs. |
| Every hero costs something, and no two on a roster send the same bill | …makes two heroes interchangeable at the till. Totals are meant to be about equal, so the bill's *shape* is what is checked. |

### 510 — the healers

| Check | Fails the day somebody… |
| --- | --- |
| **Two priests and two wounded take one each** | …breaks the claim rule, so both reach for the worst-off body while the other bleeds out. |
| **With one wounded body, both priests heal it** | …makes the claim rule deadlock instead of relaxing. That branch fires only when a team is winning, so nothing else would run it. |
| Claims are cleared at the start of every tick | …lets a claim outlive its healer. |
| A druid passes over an ally that is already regenerating | …stops spreading the druid's heals over time. |
| A curse-doctor curses the enemy most of its wounded allies are touching | …aims the curse at the wrong side, or at the nearest enemy. |
| **A druid behind an unbroken rank cannot cast the moon spike, and can once it is gone** | …lets the spike pass through friends, so the frontline stops being a targeting constraint. |
