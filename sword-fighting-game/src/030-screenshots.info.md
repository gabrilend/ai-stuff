<!-- made by scripts/build-info-pages from the comments in 030-screenshots.lua; change the comments and rebuild, not this page -->
# 030-screenshots


Takes a picture of the screen into tmp/shared-memory/screenshots/, with a
small sidecar file beside it saying what run took it: the seed, the tick,
the run's arguments. Nothing here files the picture; scripts/file-screenshots
does that after the game exits, numbering it into development-history/.

The engine delivers the picture at the end of the frame it was asked for,
so a quit asked for at the same moment waits until every pending picture
has been written.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.folder` | `dir` | (no comment in the source) |
| `M.take` | `dir, name, info` | name: a short word for the picture; info: { seed, tick, args }. |
