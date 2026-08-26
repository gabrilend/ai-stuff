# Phase 6 — Control is a dial

**Goal:** "player", "commander", "the tavern" and "GM" as four positions on one
dial rather than four systems.

**Status: complete.** All seven issues done, plus
[206](completed/206-sight-for-a-viewer-is-a-union.md), which had been open since
phase 2 waiting for scopes to exist.

## The issues

| Issue | What it established |
| --- | --- |
| [601 a scope is a record](completed/601-a-scope-is-a-record.md) | The dial, as world state. |
| [602 membership is a list or a region](completed/602-membership-is-a-list-or-a-region.md) | Two rules. There is no third. |
| [603 driven and ordered](completed/603-driven-and-ordered.md) | Style as a separate axis. |
| [604 a viewer holds several scopes](completed/604-a-viewer-holds-several-scopes.md) | Sight as a union, and the two shortcut flags. |
| [605 the tavern commands its crockery](completed/605-the-tavern-commands-its-crockery.md) | The test that this needed no new code. |
| [606 handing a scope over](completed/606-handing-a-scope-over.md) | One field changing, and what it does not decide. |
| [607 the phase six demo](completed/607-the-phase-six-demo.md) | Four seats, one table. |
| [206 sight for a viewer is a union](completed/206-sight-for-a-viewer-is-a-union.md) | **Closed.** Open since phase 2. |

## The claim, tested

`605` exists to be a test rather than a feature: **if playing a building had
needed a code path that playing a character did not, one of the earlier issues
was wrong.**

It did not. The tavern is configuration — a region scope over a room, ordered
style, `SEES_REGION`. Moving a coffee cup goes through the same membership
question, the same gauntlet, the same motion pass, and the same filter as a
player walking down a corridor, because a coffee cup **is** a thing record with a
position and an owning scope.

The demo prints all four seats with the same columns:

```
seat           membership style      things     eyes
a player       a list     driven          1        1
a commander    a list     ordered         4        4
the tavern     a region   ordered         5        1
a GM           a region   ordered        13        7
```

## What the flags cost, measured

| Seat | Sweeps | Microseconds |
| --- | --- | --- |
| a player | 1 | ~26 |
| a commander | 4 | ~71 |
| the tavern | 1, unused | ~13 |
| a GM | 0 | ~3 |

`SEES_ALL` **skips** the geometry rather than running it and winning — without it
a GM would sweep once per creature per beat, which is why it is a flag rather
than a quantity of patience. `SEES_REGION` answers about a whole room before any
sweep is reached.

That is what [4.3](../docs/016-open-questions.md) — how large a table can get —
was waiting for. A commander scales with their bodies; the two heavy seats do not
scale at all.

## An answer that emerged rather than being designed

A phase 4 leak test began failing: "hidden beats even a GM". Its own comment had
predicted it would change deliberately when scopes arrived, and it did.

Gate 1 — is this inside a scope you hold — passes everything below it, including
the hidden gate. So **a GM sees hidden things inside their own scope, because
they command them. Your own ambush is not hidden from you.**

That settles most of [6.5](../docs/016-open-questions.md) without anything being
bolted on: two GMs with whole-map scopes both see everything, and a co-GM holding
only a region sees hidden things only inside it. `MAY_SEE_HIDDEN` stays
meaningful for seeing somebody else's hidden things without commanding them.

The mechanism produced a coherent answer and the answer was adopted rather than
overridden.

## Defaults being honest about being defaults

**Standing orders survive a handover.** They belong to the bodies, not the scope,
so a new commander inherits six goblins already walking somewhere for reasons
nobody told them. That is what falls out of doing nothing, and it is recorded as
a default rather than presented as a decision.
[6.3](../docs/016-open-questions.md) stays open.

**A patrol changes hands at a doorway.** Region membership is read from where a
body *is*. The demo shows the moment rather than the mechanism deciding it, and
a test pins it so that changing it later is deliberate with a failing test
attached. [6.1](../docs/016-open-questions.md) stays open.

## Blocking open questions

- **6.1** — the patrol crossing. Now visible, still undecided.
- **6.2** — "usually weaker but not always". Nothing enforces it and nothing
  should; if it is a rule it is a *ruleset's*.
- **6.3** — orders in flight through a handover.
- **6.4** — a party of four: one driven and three following is a third thing that
  appears in no document here.
- **6.6** — can a GM see what the players have seen?
- **2.2** — union or switch, for a commander with six pairs of eyes.

## What phase 7 inherits

A dial that works, and a gauntlet with a hole in it labelled "the ruleset".
