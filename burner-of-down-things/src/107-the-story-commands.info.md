# 107-the-story-commands.lua

The `story` row of the command table (docs/012): `machine story <case>`
tells the case's ledger lines not yet told as new chapters of
`output/story/<case>.md` (103's `tell`), prints the story's path and how
many chapters were added. Holds the case lock like every row on a case, so
its own `goodbye` line waits, untold, for the next chapter.
