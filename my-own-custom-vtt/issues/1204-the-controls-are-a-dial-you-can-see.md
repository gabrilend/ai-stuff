# 1204 -- The controls are a dial you can see

**Phase:** 12, the table as it is actually played
**Blocked by:** phase 11 complete.
**Blocks:** [1205](1205-the-state-is-drawn-back-to-you.md)
**Documents:** [who controls what](../docs/008-who-controls-what.md),
[the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

The browser drives one body with the arrow keys and gives orders by clicking. A
person commanding four bodies can drive one of them.

The vision says a player controls "up to an entire party at once, but generally
not more", and nothing in the project says how four bodies and one keyboard
are supposed to meet.

## Intended behaviour

**Three dials and a handful of verbs.** A command is
*(which units) × (which direction) × (how far) × (what to do)*, and the first
three are held as state that the keys change.

### Where this comes from

A real control scheme, built by the person who asked for this, for commanding a
squad in an action game. It is worth describing precisely because the shape is
not obvious and it is much better than the obvious answers.

It is a **modal state machine made of bind files.** Loading a different file
changes what every key does. Three things are held as state — which group of pets,
which of eight compass directions, and one of three distances — and a handful of
keys apply verbs to whatever the dials are pointing at:

```
q "petcom_all goto"      1 "petcom_all passive"
e "petcom_all attack"    2 "petcom_all defensive"
f "petcom_all follow"    3 "petcom_all aggressive"
n "petcom_all stay"
```

Other keys turn the dials rather than doing anything: `6789 0` choose which group,
`U I O / H K / N M` choose a direction, `Y` and `H` step the distance out and in.
Each of those loads a different file, which is how the state is stored.

And every one of them **prints a small diagram** of where the dials now point.

### Why this is right for a tabletop and not just borrowed

**One keyboard genuinely cannot drive four bodies.** The three obvious answers —
drive one and have three follow, order all four RTS-style, drive one at a time —
are each half of what a person wants. The dial is all of it: point at all four
and say *go*, point at one and say *stay*, point northeast-far and say *attack*.

**It composes with what already exists.** The dial's output is an ordinary order
to an ordinary scope, so the two styles on the existing control dial —
[driven and ordered](../docs/008-who-controls-what.md) — are what the verbs
resolve into. Nothing new reaches the server.

**It is closed.** Four dials with small ranges is the same shape as the
paintbrush and the same shape as the wire format: a fixed vocabulary, every value
inside what its bits can hold.

### The server must not learn about any of this

**The dials live entirely in the view.** The client resolves
*(these three units) × (northeast) × (far)* into a point in the world and sends
`order-move` for each of them, which is a verb the server has had since phase 3.

That is the whole architecture restated: the server knows space, sight, things
and permission. A direction relative to a camera is not one of those, and a
server that knew what "northeast, far" meant would be a server with an opinion
about how people play.

It also means the terminal view can grow the same dial without a protocol change,
which is the phase 11 claim being cashed a second time.

## Suggested implementation steps

1. The three dials as state in the view: a selection, a direction, a distance.
2. Keys that turn a dial, separately from keys that apply a verb.
3. Resolve to a world point relative to the camera, and send ordinary orders.
4. A cycling key that walks the selection one body at a time, the way SPACE walks
   the pet list in the original.
5. Test what can be tested from outside a browser: that the resolution from
   dials to a point is arithmetic, and can therefore be checked without a browser
   at all.
