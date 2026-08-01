# Datapath — the court

*The part of the world that can be spoken to rather than about.*

## Why a cast list is a data structure

The vision asks to *"roleplay in the moment with the characters involved"*.
Taken seriously, that is not a prompt-writing decision. It is an addressing
scheme.

In a normal Dominions interface you select a commander by clicking a portrait,
and the click carries the identity. In a conversation there are no portraits,
so identity has to be carried by the name — which means names have to be
unambiguous, resolvable, and attached to everything that commander can do.
That is the court: a lookup from something a person would say to a specific
record in the world table.

    "tell Cheiron to hold the pass"
            │
            ▼
       the court ──► commander record, offset in the .2h, province he stands in
            │
            ▼
       the ledger entry, which can name all three

If a name cannot be resolved to exactly one member of the court, the system
asks. It does not pick the closest match, because picking the closest match
is how a mage ends up walking into a siege.

## What a member of the court holds

| Field | From | Used for |
|---|---|---|
| name | the commander record | addressing, and the herald's dialogue |
| where | the commander record | scene-setting, and validating movement orders |
| dossier | the province history of where they have been | continuity that is factual |
| record offset | the reading | so the hand knows which bytes to change |

The dossier is the interesting one. Province history is the game's own dated
prose — *"Early Winter in the year 2 of the ascension wars: Ancyrna was
conquered by Pangaea"* — and a commander standing in Ancyrna can be given that
sentence as context without anything having been invented. The herald voicing
Cheiron knows what happened where Cheiron is standing because the game wrote it
down, not because a model remembered it.

## Voices are constrained, not authored

Each member of the court gets a short voice note assembled from facts: their
title, their magic, their condition, what happened in the province they hold.
The herald is given that note and told to speak as them.

What the herald is **not** given is licence to establish fact. A voiced line
may express opinion, mood, fear, and preference freely — that is what the mode
is for — but any statement of what *is* must trace to the world table. The
separation is enforced where it can be and marked where it cannot:

- statements of fact in dialogue are drawn from the note, which is generated
  from the table
- everything else is understood by the record as colour, and is stored as
  colour

A commander who says "the pass is held by three hundred men" when the world
table does not know that is a bug, and it is the kind of bug that is invisible
unless the record keeps the two kinds of sentence apart.

## Who is in the court

Commanders, because they have names and take orders. Provinces are places, not
people, and are spoken about.

Two members are special and worth naming as such:

**The pretender god.** Yours. In the file read while writing this, hers is
Philia. The pretender is a commander like any other in the file and unlike any
other in the fiction, and the herald should know the difference.

**The prophet**, when one exists, for the same reason.

Everything else — independent commanders, enemy commanders glimpsed by a scout
— is spoken about, never as. The court contains only what the nation actually
commands, which falls out of the turn file being the only input.

## The scene

A conversation opens with a scene rather than a status report, and the scene is
selected, not summarised. Choosing what to open on is a real decision with a
real failure mode: a herald that opens on everything produces a wall, and a
herald that opens on the wrong thing buries the siege under a description of
the weather.

The selection is made mechanically before any model is asked to write:

1. what changed since last turn, from the chronicle
2. what the game itself reported as an event this turn
3. what the player asked about last time and did not resolve

Ranked, cut to a handful, and handed over as the things worth opening on. The
herald writes the scene; it does not choose the scene. That keeps the choice
inspectable, and it keeps a model's sense of drama from outranking a siege.

## Accessibility notes that shaped this

- A member of the court can always be asked to restate their situation, and the
  restatement is generated from the table, so it cannot drift from the previous
  answer.
- Every scene is followed by an explicit, short list of what can be acted on.
  Discovering options by exploring a map is not available to this interface and
  must not be assumed.
- Names are checked for ambiguity when the court is built, not when a command
  is parsed. Two commanders with the same name are given distinguishing
  epithets up front, so a person is never told their instruction was ambiguous
  after they have said it.

## Related

- [The reading datapath](datapath-the-reading.md) — where the court's facts come from
- [The chronicle datapath](datapath-the-chronicle.md) — where a scene's "what changed" comes from
- [The ledger datapath](datapath-the-ledger.md) — what an address resolves into
