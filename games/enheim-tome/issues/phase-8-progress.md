# Phase 8 — The Scaffold

What happens when people are in a place at an hour. Formerly "Events, and What Is
Known", which described a different and worse thing.

**Ten issues written, none complete. Six earlier ones superseded and filed.**

| Issue | State |
| --- | --- |
| [807 — an actor is a person or a place](807-an-actor-is-a-person-or-a-place.md) | not started — open question 19 |
| [808 — character is a sparse map of axes](808-character-is-a-sparse-map-of-axes.md) | not started |
| [809 — a place holds a natural character](809-a-place-holds-a-natural-character.md) | not started |
| [810 — open and closed are a line on the curve](810-open-and-closed-are-a-line-on-the-curve.md) | not started |
| [811 — the gathering is one share of N plus one](811-the-gathering-is-one-share-of-n-plus-one.md) | not started |
| [812 — the closed give and the open adopt](812-the-closed-give-and-the-open-adopt.md) | not started |
| [813 — two closed actors make an arc](813-two-closed-actors-make-an-arc.md) | not started |
| [814 — a valence changes who nearby is open](814-a-valence-changes-who-nearby-is-open.md) | not started |
| [815 — forcing a closed thing open](815-forcing-a-closed-thing-open.md) | not started |
| [816 — a minted axis needs a colour and an angle](816-a-minted-axis-needs-a-colour-and-an-angle.md) | not started |

### The six that were replaced

| Issue | Why |
| --- | --- |
| [801 — an event is a hook](superseded/801-an-event-is-a-hook.md) | an event is an occurrence, not a hook |
| [802 — an event crosses an address](superseded/802-an-event-crosses-an-address.md) | a crossing is computed, not stored |
| [803 — knowledge is held events](superseded/803-knowledge-is-held-events.md) | nothing is held |
| [804 — a knowledge filter](superseded/804-a-knowledge-filter.md) | an axis is a filter, so there is no separate one to build |
| [805 — one event per block](superseded/805-one-event-per-block.md) | nothing is written per block |
| [806 — houses fill in forever](superseded/806-houses-fill-in-forever.md) | the campaign it plans does not exist |

They are in [issues/superseded/](superseded/README.md), kept rather than deleted,
each banner-marked with what replaced it.

**The new tickets start at 807 rather than reusing 801.** Two different designs
sharing a name would make the record ambiguous, and the retired tickets have to
stay findable under the names everything already refers to them by. Within 807 to
816 the ordering is still foundational-first.

## What this phase was, and why it stopped being that

The phase described a hidden layer of authored facts. One per block, then one per
house, each a small concrete secret — a key in a box on an endtable, opening a
chest across the yard. A person's knowledge was the set of those they held, and a
filter was a count of held ones.

It was internally consistent and it was refuted by its own arithmetic. The
document priced two thousand block facts at one to two months, and twenty to forty
thousand house facts at **two to four years**, and then called that "the only
version that ever ships." A design whose own text states a four-year authoring cost
before the game works has already failed; it had simply not noticed.

The wording gave it away before the arithmetic did:

> "holding an event" doesn't make sense unless you mean "holding a party" or
> "throwing a party" or "playing catch" or "tossing grenades".

The noun and the verb disagreed. An event was defined as an object sitting in a
box, and the verb attached to it was possession. You do not hold a party.

## What replaced it, and the order the pieces arrived in

**Derivation instead of authoring.** Character is computed from where people are
and what they are like, rather than read out of a written pile. Nothing is
authored except the tracing, which was always a separate campaign.

**A place's character is its visitors, plus one share of its own nature.** Stated
exactly: five people in a room makes the room one sixth. That deleted a tunable
constant and replaced it with a rule that behaves correctly at every scale on its
own — an empty room is entirely itself, a person alone at home is half the
building, and a crowd of fifty is its crowd rather than its stones. A place's
resistance to change is inversely proportional to how busy it is, and nobody tuned
that.

**Axes are minted, not declared.** There is no fixed list of dimensions. A place
grows them as it develops a nature, arbitrarily many, and the word one gets is
generated at the moment of mixing rather than chosen from a vocabulary — "ashen"
and "consumed" describe the same burning and are two different spirits.

**Open and closed, and the direction that was backwards.** The first reading was
that open means participating in exchange. It does not. **Open means open to being
changed.** Exchange is unconditional and always happening; the statuses only set
which way it runs, and it runs **from the closed to the open**. The closed thing is
the source rather than the withholder.

**Sparks.** Two closed actors cannot transfer, so what they make is new. Intent is
required — usually they bounce off — and where the result lands is context: the
room, a bystander, or nowhere.

## Three things the existing design turned out to have been built for

None of these were planned. They were found already in place while the replacement
was being worked out, which is the strongest evidence the replacement is right.

**The time-curve was always the instrument.** Document 008 defined a person's day
as activity across the hours and wrote that "a curve pinned high all day is telling
you something about that person" — without saying what. It is telling you they are
never open. A line across that curve is the whole of the open/closed rule, and the
widget that draws it was already in the tome.

**The filter record was always the axis record.** Document 006 defines a filter as
a name, a colour, an angle, a mode and a reading of `(person, place) → a number or
nothing`. A minted axis is exactly that. And answer A9's ruling that any number of
filters may be active at once — weaving rather than stacking, "because flat
stacking goes to mud at three" — was load-bearing for a reason nobody knew, since
the filter list is now unbounded and grows on its own.

**The quadrant was always the cause.** Document 003 called the quadrant a social
horizon: somebody in the north-east can wander all day and never cross anyone from
the south-west. Under minting-by-unlike-meeting, a quarter where everybody only
meets people like themselves mints nothing, ever. The rigidity the whole game is
about is not a mood applied to the city. It is a property of its partition.

## The sentence that became machinery

Document 003 says its own design is contained in one line from the vision:

> The building is stone, and can't adjust easily, meaning it's what roots people.

Two scaffold rules touching make that literal. Stone is closed, so it gives and
never receives. A person is open when at rest, and a person rests at home. So the
only hours anybody can be changed at all are the hours spent inside a building
broadcasting at them that cannot be broadcast back at. **You become the
architecture during the only hours you are able to become anything.**

Nothing was written to produce that. It is what the rules say when put beside each
other.

## What the phase now refuses to decide

Recorded because these look like gaps and are not. The instruction was to build the
scaffold upon which a context might develop, rather than to enumerate the contexts:

- what any particular arc means
- whether a given conflict is productive — it depends entirely on the context
- what word a minted axis gets — generated at the moment of mixing
- what fills the intent slot

## Still owed by this phase

- Nothing is built. All ten tickets are blueprints; `src/` is still empty, and
  building is deliberately held until the system is fully defined.
- **What fills the intent slot** in [813](813-two-closed-actors-make-an-arc.md).
  Named so that it exists; not settled, and a spark cannot happen without it.
- The words. [Phase 9](phase-9-progress.md) now covers them &mdash; see
  [the scene](../docs/010-the-scene.md) &mdash; so this is no longer owed here, but
  phase 8 is not usable on its own without it.
- What the **person** half of a filter's reading means now. An axis belongs to the
  place, so the parameter that carried knowledge has nothing obvious left to do,
  and character switching was the design's best idea. Raised as
  [question 18](../docs/013-open-questions.md).
