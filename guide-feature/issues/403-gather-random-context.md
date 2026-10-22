# 403 — Gather random context

phase 4, the thinkers

## Current behavior

Nothing exists.

## Intended behavior

The vision: "with as much other context stuffed in ram as they are able.
just... random stuff. stuff that's relevant. from the project directory.
maybe. randomly selected".

The context gatherer:

- **in**: a context folder (path string), a token budget (whole number), a
  token-counting function (from the backend, 401), a seed (whole number);
- **out**: a list of excerpts, each a record of file path (string relative to
  the folder), first and last line (whole numbers) and text (string), whose
  total tokens fit the budget; plus the seed and the files looked at, for the
  log.

It picks files at random, skipping binary files and anything matched by the
folder's `.gitignore`, and takes a random run of lines from each, until the
budget is full. The seed makes a turn reproducible.

The folder is read once at the start of each turn into memory. Excerpt
picking is done on that in-memory copy, which is what "stuffed in ram" means
here.

## Suggested implementation steps

1. File listing and the binary check (a zero byte in the first 4 KiB).
2. Random excerpts until full.
3. Tests with a fixed seed on a small fixture folder.

## Related documents

- `docs/datapath-thinker.md`, step 2

## Open questions

- Which project, and how its files reach the fg-sora
  (`docs/open-questions.md`, 1).
- "stuff that's relevant": should picking lean toward files that share words
  with the current page, using the similarity measure (104), rather than
  being purely random?

## Blocked by

None.

## Blocks

404.
