# 143-what-rides-inside — info

Where the model, the text and the carried randomness sit inside the one file a
firmware opens. Issue `502`.

## Invocation

```lua
local rides = dofile(DIR .. "/src/143-what-rides-inside.lua")
local plan = rides.plan({ model = bytes, text = bytes, randomness = bytes })
-- plan.at.model, plan.at.text, plan.at.randomness -- offsets from the blob's start
-- plan.bytes                                      -- the blob itself
-- plan.size                                       -- how long it is
local expected = rides.expectations(plan)          -- the same thing, for a seam check
```

A part that is absent takes no room and is given no offset, so a caller can ask
what a machine carrying no randomness would look like without inventing an empty
one.

## Why it exists

**Three arrangements of the same five things existed in this project and only
two were ever read.**

`029` puts an appended blob a fixed distance past the code, and the machine finds
it by measuring from where it is standing. Real; it is what boots.

`140` divided that blob into model, text and randomness — **inside a test**,
where nothing else could reach it. Also real, also what boots.

`089` laid five regions down at block boundaries, in a different order, with
different alignment, and checked them against expectations typed out again by
hand in its own test. **Nothing has ever read that arrangement.** It was correct
and it described a machine nobody built.

So the layout that was real lived in a test, and the layout that was documented
lived in a builder. This is the real one, moved somewhere both can reach.

## What it deliberately does not know

Where the blob itself goes. That is `029`'s business — a fixed distance past the
code, so a payload that outgrew the distance is refused rather than having its
own instructions read as weights. Splitting the two means neither has to know
the other's number.

## What checks it

`140`, and it is the strongest check available: a computer with no operating
system boots, finds its own weights at these offsets, thinks, and says the same
six words it said before this file existed. The move out of the test was proved
byte-identical by the machine still working.

## The alignment is history, not a requirement

Sixteen bytes. Nothing here is loaded by a processor that cares. It is the
arrangement `140` has been booting with since the driver first spoke, and
changing it would change where a working machine looks for its own weights.
