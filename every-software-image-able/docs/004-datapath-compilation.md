# 004 — Datapath: Compilation

The chain the seed page gives as the machine's floor: **text to source to a
runnable program**, where both arrows are allowed to improve rather than being
fixed machinery.

## Why it cannot be a fixed compiler

The first translation happens with nothing underneath it. No compiler exists yet,
the processor is one nobody surveyed in advance, and the output has to be
assembly because there is no language available that needs less. The model is the
compiler until it has written one, and what it writes is shaped by a machine it
only just finished measuring (`003`).

After that the chain keeps improving, but the reason it started improvable is
that it started with nothing to be fixed *to*.

## When the machine looks for a better way

Not continuously. **Nothing is measured until a demand arrives from somewhere
else that needs performance of a particular kind.** There is no background
watching, no standing comparison, no speculative generation of alternatives. The
examination is the expensive part and it is triggered rather than scheduled.

This is not a reluctance to switch — it is not looking at all until asked.

**Demand**

| Field | Type | Meaning |
|---|---|---|
| `demand_id` | integer | which demand |
| `aspect` | integer | which kind of performance is short — the colour (`006`) |
| `origin` | integer | which part of the machine is constrained |
| `target` | string | which piece of software is being asked to improve |
| `raised_at` | integer | when |

The aspect is load-bearing. "Make this better" has no direction; "this is short
on the aspect that reads as *this colour*" names both what is wrong and which
axis to vary along. The machine already tags every status it emits with an
aspect, so a demand costs nothing extra to describe.

## What gets optimised

Whatever is holding the machine back. There is no fixed metric and no weighted
sum of metrics — there are many parameters, and the one that matters is the one
currently furthest from ordinary.

That measurement already exists. `006` describes a magnitude that every program
reports after everything it does, on an axis where fifty is ordinary and distance
in either direction means attention is warranted. The parameter furthest from
fifty is the one the compiler should be working on. **One reading, two
consumers:** it trips the intercession when it goes far enough, and it names the
objective when a demand arrives.

## Trying a different way before moving on

When a constraint is being worked, the machine tries **different approaches to
that same constraint** before it is permitted to go work somewhere else. The loop
iterates over approaches to one problem, not over problems.

This removes the failure that a threshold-based rule would have needed to guard
against. A machine that switches targets whenever another parameter looks worse
ping-pongs between two constraints forever, relieving each one just enough to make
the other binding, and never properly solving either. Staying until the ideas run
out cannot ping-pong.

What it costs instead is grinding — spending attempts on a constraint whose space
of approaches is genuinely empty. So the number that matters is not a threshold
but **how many different ways are tried before moving on**, and it is not chosen
yet.

**Approach** — one way of doing something, kept.

| Field | Type | Meaning |
|---|---|---|
| `approach_id` | integer | which approach |
| `target` | string | what it is an approach to |
| `aspect_favoured` | integer | which kind of performance it is good for |
| `situation` | string | when it should be preferred |
| `measured` | table | array of `{aspect = integer, value = number}` |
| `superseded_by` | integer | another approach, or -1 |

Approaches are not discarded when a better one is found, because "better" was
measured under one demand and the next demand may come with a different colour.
The machine keeps several ways of doing the same thing and selects among them by
situation.

## Every step carries a picture

The machine explains why something was built the way it was, with statistics and
graphs, and picks the one that best solves the problem. The explanation is not a
report written afterward — it is the mechanism by which the choice is made
legible, and it lands in the bootstrap rather than in a late phase, because a
machine that cannot draw cannot justify anything it does.

Clarity has a definition here, and it is precise:

> distance from alternatives when more accurate to the truth than alternatives

Two parts, and the second is what makes it a real quantity rather than a feeling.
Distance alone is not clarity — being far from every alternative while wrong is
isolation. Clarity is margin *in the correct direction*.

That gives the drawing a rule with consequences: **a picture must show the field,
not the winner.** A chart with one bar carries no clarity by this definition,
because the distance is not visible in it. The approaches that lost stay on the
page, at their measured positions, so the margin is something a reader can see
rather than something the machine asserts.

**Justification**

| Field | Type | Meaning |
|---|---|---|
| `justification_id` | integer | which one |
| `demand_id` | integer | what prompted the examination |
| `approaches` | table | array of `approach_id` — every one considered, not only the chosen |
| `chosen` | integer | which won |
| `margin` | number | distance from the runner-up, along the demanded aspect |
| `picture` | string | where the drawing lives |

## When there is no approach to vary

Fitting for what would have had to be different searches over the values of code
that exists. If the machine did not reach the state it wanted because of a case
nobody handled — a branch that was never written — no fit will find it, because
there is no parameter to move.

That is not a silent failure. **It is the trigger.** Having nothing to vary is
precisely how the machine detects that the software it needs does not exist yet,
which hands the problem to rung three (`005`) and is, in the seed page's terms,
the whole point of the project.

## Open questions

- **How many different ways before moving on?** Named above; unchosen. It decides
  whether the machine converges or grinds.
- ~~What draws the picture before there is a display?~~ **Answered.** The
  firmware hands over a linear framebuffer — an address, a geometry and a pixel
  format — so writing bytes changes pixels with no driver involved. The machine
  can draw from its first instant, and a chart showing what a choice was made
  against is available immediately rather than in a late phase (`202`).
- **Does an approach ever get deleted?** Rung four condenses duplication, and two
  approaches to the same thing look exactly like duplication from the outside
  while being the thing that makes situational selection possible.
