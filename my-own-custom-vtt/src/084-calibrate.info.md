# 084-calibrate

A program that answers one question: **are the machine grader's five tiers still
five tiers?**

## What it is, for somebody who has not opened it

The code that draws sprites judges each one and files it under a tier from one to
five. The lines between the tiers are four fixed numbers living in
`sprite_machine_cut`. This program makes a great many sprites, counts what tier
each lands in, and reports whether all five are being used or whether four fifths
of everything is piling into two of them.

## Why it ships instead of being a script somebody ran once

The four numbers are frozen. The thing they measure is not.

Add a shape to the paintbrush, change how large a body is drawn, weight the
grader differently — and the distribution slides underneath the lines. Tier five
quietly comes to mean "the best third" instead of "the best tenth". Nothing
anywhere complains, every rating recorded against a tier starts describing a
different pool than it did, and the only symptom is not liking the output some
months later.

The only defence is being able to re-measure cheaply whenever the generator
changes. So this is a program, not a memory.

**It reports; it does not fix.** The four numbers stay in the source where they
can be read and argued with.

## Running it

| Invocation | What it does |
| --- | --- |
| `084-calibrate` | four thousand seeds across eight categories |
| `084-calibrate 40000` | that many seeds per category |
| `084-calibrate 4000 --histogram` | also print every score, its count, and a bar |

Eight categories rather than one, because the category is folded into the stream
name — a calibration against a single word is a calibration against one corner of
the space, and would look perfectly convincing.

Exit status is 0 when the tiers hold and 1 when they are stale, so a build or a
hook can ask without reading the text.

## What it prints

The range of scores actually produced. A table of tier against share against the
share that was intended. Where each cut line would go if it were measured today,
beside where it currently is.

Then a verdict. A tier drifting more than six points from its intended share is
called adrift; six because the sweep is a sample and a tier that wanted twenty
per cent and got twenty-two has not gone wrong.

**An empty tier is always stale**, however small its intended share. A number
nothing ever lands on is not a lenient grade — it is a grade that does not exist
while looking like one.

## The intended shares

Ten, twenty, forty, twenty, ten. Most sprites are middling, few are excellent,
few are poor.

## Related

- [082-sprite](082-sprite.info.md) — the grader itself and where the cut lines came from
- issue [905](../issues/completed/905-the-machine-grader-is-a-heuristic.md)
