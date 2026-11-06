# 077-the-lane-deck

The lane's deck asked directly, wave after wave, without a match around it.

## Running it

```
luajit tests/077-the-lane-deck.lua
```

Exits non-zero if anything failed. `./run-tests` runs it in the running half. It takes
a fraction of a second: most checks call the deck the way the spawner does, hundreds of
waves at a time, on a world that never ticks.

It claims 213 for the half that is built and for the three tests 213 asks for. What
upgrades do to a deck, and bearing placement, are not built and not tested.

## What it checks

| Check | Fails the day somebody… |
| --- | --- |
| The shuffle deals 3, 4, 5, 4, 7, then leads with the next odd count, every other pass four | …replaces the pile shuffle with a random one, or drops the four. |
| A shuffle keeps every card exactly once, and moves them | …loses or duplicates tickets. |
| **Over three hundred waves a lane fields every kind, none more than half** | …lets one kind take over a lane. |
| Heavy infantry is the rarest kind | …makes the dearest kind common. |
| A wave is about the size it was, give or take one | …changes how much a lane can field by a lot without meaning to. |
| **No wave ever holds three of a kind**, none is over the body cap, and none breaks its commander's share | …breaks the never-three rule or the commander's proportion. |
| **A lane that fielded heavy infantry ends the wave with less in its purse, and fields a lighter wave after** | …makes cost stop feeding back. Lighter rather than smaller, because the line is capped at four and a poorer lane loses its dear bodies rather than its count. |
| After a wave the undrawn tickets are still on top, in order, with the discards under them | …puts the discards back on top, or loses them. |
| A meter at its doubling walks a kind out undrawn, then starts again | …breaks the guarantee that a kind cannot vanish. |
| Carrying more never costs less, nothing is free, and heavy kit is the dearest | …lets cost stop following weight. |
| Every body of the first waves but the captains came from the deck | …leaves a path that still raises the old fixed wave. |
| **The two sides' first waves are the same bodies in the same kit** | …draws kit from a stream named per team, so an untouched match is no longer a mirror. |
| Every body wears exactly its row and its kit, and some drew something optional | …drops a piece, or adds one twice. |
| A sweep that rebuilds every body from its row gives each its kit back | …stores kit somewhere `give_body` does not read, so a boon strips everybody's armour. |
