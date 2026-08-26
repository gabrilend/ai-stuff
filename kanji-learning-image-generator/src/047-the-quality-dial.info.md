# 047-the-quality-dial — info

Turning the quality up on one kind of picture, and being told what that costs before it costs it.

For a general: the exchange this exists for is

```
    the forest ones are looking pretty bad -- can we raise their quality?
  > raising forest from 3 to 4 leaves 31 to draw from instead of 214, so
  > expect them to start resembling each other.
    that's fine.
  > do you want to look through the 47 nobody has rated? it would take a few
  > minutes.
    not now.

```

Four things are in that exchange and all four are requirements here.

THE FLOOR IS PER KIND AND SET WHEN IT IS USED. Not a global setting and not something compiled in. Quality is a thing you turn up on *the forest ones* because the forest ones are what is bothering you.

RAISING IT COSTS VARIETY AND THAT IS SAID FIRST. The size of the surviving set at the current floor and at the proposed one, at the moment of choosing rather than afterwards in the output. This is the same axis that decides whether a trained thing memorises or wanders, pulled out of the internals and put where a person can reach it.

PROVENANCE IS A SECOND DIAL. "Tier 4 or better" and "tier 4 or better as judged by a person" are different requests; the second is smaller and more trustworthy. Confidence and quality are not the same axis, and collapsing them loses the difference exactly when it matters.

RE-RATING IS OFFERED WITH ITS COST ATTACHED, AND DECLINING IS FREE. A studio that nags is a studio nobody opens.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `047-the-quality-dial.lua` and
run the sweep again.*

## Invocation

```
luajit src/047-the-quality-dial.lua --category forest --floor 4
```

## What it offers

| | |
|---|---|
| `M.consider(settings, category, floor, by_a_person)` | What a floor would leave, at every tier, before anybody commits to one. |
| `M.describe(report, from_floor, to_floor)` | The trade, in the words somebody would use. |
| `M.choose(settings, wanted)` | The pictures that survive a floor -- and the report, always, first. |

### `M.consider(settings, category, floor, by_a_person)`

What a floor would leave, at every tier, before anybody commits to one.

Returns the whole ladder rather than one number, because the question is never "how many at four" on its own -- it is "how many do I lose by going from three to four", and that needs both.

### `M.choose(settings, wanted)`

The pictures that survive a floor -- and the report, always, first.

The report is not optional and cannot be turned off. A filter that quietly returns thirty-one things where there were two hundred is the failure this whole file exists to prevent, and making the telling optional is how it would come back.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `035-test-the-machine`.
