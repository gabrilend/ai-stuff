# 403 — Pictures kept

## Current behavior

Nothing exists. Needs `204` and `402`.

## Intended behavior

**Once a quantity has a picture, hovering it again shows the same picture
straight away. Only a middle-click asks for a new one.** The owner: "we should
cache them to redisplay unless middle-clicked".

So the cache has two levels:

- **what this quantity is showing** — keyed by the page address, the
  paragraph's text and the quantity's character position. Holds the analogy
  record and the picture currently shown for it. Hovering again redisplays
  it. A middle-click (`502`) replaces it with the re-roll's result.
- **pictures by scene** — keyed by a checksum of everything that decides a
  picture: the scene text, the cell layout, the checkpoint, size, steps,
  sampler, seed. Two quantities that produce the same scene share one picture
  and it is drawn once.

**Where the cache lives is a setting with two modes**, both built and both
tested:

- **RAM** (the default) — `tmp/shared-memory/pictures/`, fast, emptied by a
  reboot
- **disk** — a folder named in the settings file, kept across reboots

Each entry is the PNG and a small record beside it: the scene, the settings,
the quantity it was made for, when, and how many times it has been shown. A
size limit (a setting) drops the least-recently-shown pictures first.

Saving a chosen picture somewhere of the reader's own is `503`.

## Suggested implementation steps

1. `src/` — the two cache levels: key, look up, store, drop.
2. The settings file gains the mode, the disk folder and the size limit.
3. Tests, run once per mode: hovering the same quantity twice submits once;
   a middle-click submits again and replaces what is shown; a changed setting
   misses the scene cache; the disk mode's pictures survive a host restart.

## Related

`docs/005-datapath-the-picture.md` · needs `204`, `402` · blocks `404`, `503`
