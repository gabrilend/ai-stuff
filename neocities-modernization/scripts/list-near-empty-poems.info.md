# list-near-empty-poems.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/list-near-empty-poems: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Lists posts with almost no words in them, as candidates to hand-pick for
leaving out of the similar, different and word-cloud pages.

General description (for a CEO): a post like "\" or "brb" gives the machine
that turns writing into numbers almost nothing to read, so it lands in the
middle of everything and turns up as a "similar" poem for hundreds of
unrelated pieces. These posts still belong in the timeline. This script
does not decide anything; it prints a short list, most-intrusive first, in
the exact shape config.lua takes, so a person can copy the ones they agree
with.

How a post is measured:
  letters  -- count of ASCII letters and digits after removing @mentions and
              links (an "@user-1074 thanks" has six letters, not sixteen).
  lists    -- how many other poems' top-33 similar lists it appears in, read
              from the chosen model's similarity_rankings_cache.json. The
              typical poem appears in about two dozen; a near-empty hub in
              hundreds. Only shown when --model is given and that model's
              cache exists.
Pictures (image-only posts) are skipped: having no text is what they are.

Usage:
  scripts/list-near-empty-poems [--dir PATH] --max-letters N [--model NAME]
    --dir PATH     project directory (default: the hard-coded one below)
    --max-letters  include posts with at most this many letters/digits
    --model        embeddings directory name, for the "lists" column

Output IDs match what config.lua's poem lists expect per category:
  fediverse / fediverse_boost / messages: the four-digit file number
  notes:     the original filename without extension
  bluesky:   the number poems.json gives it (bluesky has no file name)
```

## Inside (local to the file)

### `parse_arguments(argv)`
(No comment above it in the source.)

### `read_all(path)`
(No comment above it in the source.)

### `count_letters(text)`

```
Mentions and links are addressing, not writing; counting them would let
"@user-1135 @user-1103 @user-1074 Do tell" look like a thirty-letter post.
```

### `config_id(poem)`

```
The identifier each extractor checks the exclusion lists against.
```

### `load_list_counts(model)`

```
How many top-K similar lists each poem_index appears in. nil when no model
was named; an error when one was named but its cache is missing, because a
silently absent column would read as "every post is harmless".
```
