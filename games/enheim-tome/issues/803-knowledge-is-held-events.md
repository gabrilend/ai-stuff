# 803 — Knowledge Is Held Events

| | |
| --- | --- |
| Phase | 8 — Events, and What Is Known |
| Blocked by | 502, 801 |
| Blocks | 804 |
| Reads | [events and what people know](../docs/009-events-and-what-people-know.md) |
| Open questions | **17** — how an event passes from one person to another |

## Current behavior

Events exist in the world. Nobody knows anything.

## Intended behavior

**A person's knowledge is the set of events they hold.** That is the whole of it.

No discovery flags. No fog to lift. No second system.

### It is the same system as the filters

This is the point worth being explicit about, because it looks like two systems
and is one.

A filter reads a place **for a person** — [502](502-a-reading-takes-a-person.md).
A filter asking *what do you know of hidden things here* is a count of the events
this person holds at this address. A filter answering *nothing* for a place is
this person holding none there.

**Nothing bridges knowledge and the map, because there is nothing to bridge.** The
hatching is already a picture of what somebody holds.

That is why the fog-of-war subsystem does not exist, why there is no confidence
channel, and why ignorance renders as bare painting — all three fall out of this
one arrangement rather than being built.

### The key does not know it is a secret

An event belongs to the world; **knowing it belongs to people**. The same fact may
be held by nobody, by one person, or by half a quarter, and the fact itself is
unchanged by that.

So holding is a relation between a person and an event, stored apart from both. Not
a flag on the event — an event with a `known` field could only be known or not,
rather than known by particular people, and the whole per-person design would
collapse into a single global state.

### How it spreads

The vision says people who know a fact "keep track of it and incorporate it going
forward". Whether telling somebody costs anything, whether it can be wrong,
whether it can be lost — **all open**, see question 17.

It matters more than most of what is undecided: it is the mechanism by which a
city gets united, which is the premise. Everything else in this design is the
instrument that would show it.

This issue builds **the holding**, not the spreading.

## Suggested implementation steps

1. A relation between person and event, stored apart from both, with fast lookup
   in both directions — who holds this, and what does this person hold.
2. Query: the events a person holds at a given address, at any level of the
   containment chain.
3. No field on the event about being known. If one appears, the per-person design
   has been lost.
4. Seed fixture people with a handful of held events for testing.
5. Test that two people over the same city hold different sets, and that the same
   event held by both is one event.

## Related documents and tools

- [Events and what people know](../docs/009-events-and-what-people-know.md)
- [Open questions](../docs/012-open-questions.md) — question 17
