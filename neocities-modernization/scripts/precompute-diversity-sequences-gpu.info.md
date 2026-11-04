# precompute-diversity-sequences-gpu.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/precompute-diversity-sequences-gpu: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
precompute-diversity-sequences-gpu -- the "different" walks, on the GPU.

WHAT IT DOES (for a CEO): for every poem, builds the list of poems most
unlike it -- each step takes the poem furthest from everything picked so
far, checking every remaining poem -- and stops after the poems the pages
show (pages x poems per page). Run by run.sh stage 8.

Usage:
  scripts/precompute-diversity-sequences-gpu [--dir PATH] [--model NAME] [--output PATH] [--save-binary]
    --dir PATH     project folder (default below)
    --model NAME   the embedding model, when run on its own (a build names
                   it on the run notepad)
    --output PATH  write the cache to PATH instead of the model folder, to try
                   the step without replacing the cache a build reads
    --save-binary  also save the raw GPU sequences (debugging)
  PAGES and POEMS_PER_PAGE (environment) set how far each walk goes;
  config.lua's pagination values otherwise.

--help: print the header above and exit, before any work (libs/script-help.sh)
```
