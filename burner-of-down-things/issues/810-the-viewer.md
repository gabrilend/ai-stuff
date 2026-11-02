# 810 — The viewer

A raylib program that shows the pool — stills, clips, text, source — and takes a tier from a keypress. It reads only finished files and cards; it shares no code with any maker.

## Current Behavior

The viewer without its window is built: `src/144-the-viewer.lua` lists
exactly the assets the count utility counts, each with its category, kind
and tier; keys 1-5 append a person's rating to the selected asset; `]` and
`[` say what raising or lowering its category's floor would leave and `y`
sets it; and each frame is a draw list (ground, tiles, pictures, labels,
the selection, the status line), with assets a floor leaves out drawn dim.
Checked with no display by `tests/145-checking-the-gallery.lua` and
`tests/146-checking-the-viewer-keys.lua`. The raylib window — a thin
front handing key names in and drawing the draw list — waits on raylib
being vendored into `libs/`; until then assets are still looked at in
whatever program opens them.

## Intended Behavior

A gallery in the owner's look: black or gray ground, each asset with its category and tier; keys 1–5 append a rating to the asset's card; a floor per category can be raised and shows what it leaves.

## Suggested Implementation Steps

1. The gallery. **Test:** it lists exactly the assets the count utility counts. Done.
2. Rating from the viewer. **Test:** a keypress appends one line to the right card. Done,
   headless: the key arrives by name, as the window will hand it in.
3. The raylib window: open it, hand raylib's keys in by name, draw each
   frame's draw list. Waits on raylib in `libs/`.

## Decisions

- docs/010 question 11 is answered (2026-11-02, the coordinator for the
  owner): the window opens on the owner's own computer; here, everything
  that can be checked without a window is checked, and drawing has a path
  that runs without one. So the viewer is split: this file is everything
  but the window, and its frame is a draw list (`clear`, `rect`, `image`,
  `text`) that a thin raylib front draws command by command.
- A rating's line is appended beside the card (809b's `.ratings`), not
  into the card itself: "one line to the right card" is the card's own
  ratings file, and the card is never rewritten.
- A floor is never set by the key that proposes it: `]` or `[` puts the
  floor's cost on the status line (809d's report), and only `y` next sets
  it; any other key leaves it as it was.
- The gallery walks `.card` files exactly as the count utility does, so
  the two cannot disagree; it reads cards, ratings and the floor table,
  never an asset's bytes (a still's picture is the window's to load).
- An asset's kind comes from its ending: `.png` a still; `.gif` and
  `.mp4` clips; `.txt` and `.md` text; anything else with a card source.
- Grounds and ink as colours (black 0,0,0; gray 40,40,40; white; night
  ink bright on dark, day ink dark on white) live in the viewer for now;
  the flair's colours are 801c's.

## Blocked by

- 809
