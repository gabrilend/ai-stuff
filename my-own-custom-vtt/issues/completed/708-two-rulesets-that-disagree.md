# 708 -- Two rulesets that disagree

**Phase:** 7, the rules layer
**Blocked by:** [705](705-a-ruleset-may-refuse.md),
[706](706-what-a-viewer-may-know.md),
[707](707-dice-come-from-named-streams.md)
**Blocks:** [709](709-the-phase-seven-demo.md)
**Documents:** [the rules layer](../docs/011-the-rules-layer.md)

## Current behaviour

The hooks exist. Nothing has been written against them.

## Intended behaviour

**Two sample rulesets, deliberately unlike each other**, over one unchanged
server.

One ruleset proves the interface exists. Two prove it is an interface. If the
second one needs a change to the server, then the first was not a ruleset — it
was the game, wearing a ruleset's clothes.

### What they should disagree about

Not cosmetics. The disagreements have to be in places the server would have been
tempted to have an opinion:

| Question | Ruleset A | Ruleset B |
| --- | --- | --- |
| Turn structure | Initiative order; refuses commands out of turn. | None. Everybody acts whenever. |
| What is public | Everybody's numbers are visible. | Nothing is, ever. |
| What a `kind` is | Named creatures with statistics. | Abstract tokens with a colour. |
| Movement | Limited per turn, refuses past it. | Unrestricted. |
| Dice | A twenty-sided roll against a target. | A pool of six-sided, counting successes. |

**Ruleset A should feel like a game with rules. Ruleset B should feel like a
tabletop with none.** If both work, the server has no opinions.

### The demo is the point

This issue exists so [709](709-the-phase-seven-demo.md) can run the same world
under both and show them disagreeing — about what is legal, what a thing is, and
who may know what — with the server unchanged between them.

### They are not meant to be good games

They are meant to be **different**. A sample ruleset that is trying to be a good
game grows until it is the only game the interface fits, which is the failure this
issue exists to prevent.

## Suggested implementation steps

1. Write A: initiative, movement limits, hit points visible to all.
2. Write B: no turns, no limits, nothing visible.
3. Make both use dice, differently.
4. Confirm the server's source is untouched between them. **If it is not, say
   which file changed and why** — that is a finding about the interface, not a
   detail.
5. Keep them in a `rulesets/` directory, numbered, so reading them in order is a
   story like everything else.
