# 810 — The viewer

A raylib program that shows the pool — stills, clips, text, source — and takes a tier from a keypress. It reads only finished files and cards; it shares no code with any maker.

## Current Behavior

Assets are looked at in whatever program opens them.

## Intended Behavior

A gallery in the owner's look: black or gray ground, each asset with its category and tier; keys 1–5 append a rating to the asset's card; a floor per category can be raised and shows what it leaves.

## Suggested Implementation Steps

1. The gallery. **Test:** it lists exactly the assets the count utility counts.
2. Rating from the viewer. **Test:** a keypress appends one line to the right card.

## Blocked by

- 809
