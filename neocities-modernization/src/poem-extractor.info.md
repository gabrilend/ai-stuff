# poem-extractor.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/poem-extractor.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
poem-extractor.lua: Stage 3's reader -- every export becomes one list of poems.

WHAT IT DOES (for a CEO): reads the fediverse posts, boosts, messages,
notes and Bluesky posts the earlier stages unpacked, keeps each one's
text, date, pictures and content warning, numbers them all by date
(Issue 8-019), and writes them to assets/poems.json for every later stage.
main.lua --parse-only calls it in a build; other programs load it for its
text helpers.

Usage: luajit src/poem-extractor.lua [--dir PATH] [-I]
  --dir PATH project folder (default below); -I  ask before each step

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.load_extracted_json(input_directory)`
(No comment above it in the source.)

### `M.detect_input_mode(base_directory)`
(No comment above it in the source.)

### `M.number_poems(poems)`

```
Gives every poem its source key and its number (Issue 8-019).

The source key names the poem by its source and that source's own counting
number: "fediverse-2339", "messages-618", "notes-41". It is what links,
anchors, page names and cached vectors hold on to. A counting number can
shift when an earlier item of that source leaves (a deleted post, something
removed because it put someone at risk) or an older note arrives, and that
is accepted (owner, 2026-10-22: "Let's just shift everything down"); a
shift in one source never moves another source's keys.

The number (poem_index) is counted fresh every run, 1..N, in date order,
ties broken by source key (owner: "recomputed each run ... just counting
in a specific order with a specific method"). Nothing stored keeps it as
an identity: every cache made from the numbers records the numbering's
fingerprint (a code made from the keys in order), and a reader refuses a
cache made under another numbering.

poems  : list of poems, each with category, id (number) and a date
returns: the same list, sorted and numbered, and the numbering's
         fingerprint (string). Two poems with one key, or a poem with no
         date, stop the extraction with the poems named.
```

### `M.extract_poems_auto(base_directory, output_file, opts)`

```
opts.include_boosts (default true) controls whether reshared "boost" posts
are kept. The caller resolves CLI-flag-over-config and passes the boolean.
```

### `M.extract_poems(input_file, output_file)`
(No comment above it in the source.)

### `M.main(interactive_mode)`
(No comment above it in the source.)

### `M.extract_pure_poem_content(processed_content)`
(No comment above it in the source.)

### `M.extract_pure_poem_content_for_embedding(processed_content)`

```
Enhanced version of extract_pure_poem_content for embedding generation
Issue 6-033: Additional preprocessing for better embedding quality
Key differences from extract_pure_poem_content:
  1. Converts dashes to spaces (better tokenization: "cannabis-mentioned" → "cannabis mentioned")
  2. Strips file path metadata that leaked into content
  3. Strips separator lines (----)
  4. Isolates single poem if multiple are concatenated
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `relative_path(absolute_path)`
(No comment above it in the source.)

### `load_json_file(filepath)`
(No comment above it in the source.)

### `is_image_only_post(poem)`

```
Issue 9-004: Detect if a poem is an "image-only" post
Image-only posts have attachments but minimal text content (just emoji or <10 chars)
These posts cannot be meaningfully embedded because there's no semantic content
```

### `parse_iso8601_timestamp(timestamp)`

```
Parse ISO 8601 timestamp to Unix epoch for comparison
Handles formats like "2024-03-15T10:30:00Z" or "2024-03-15T10:30:00.000Z"
```

### `mark_image_only_posts(poems)`

```
Issue 9-010: Mark image-only posts and find nearest text poem for embedding inheritance
Images stay on their original post; embedding inherits from nearest text poem
This replaces the old association system from Issue 9-004
```

### `extract_poem_info(header_line)`
(No comment above it in the source.)

### `parse_compiled_file(filepath)`
(No comment above it in the source.)

### `assign_nearest_text_poem_index(poems)`

```
Issue 9-010: After poem_index is assigned, map nearest_text_poem to poem_index
This allows the embedding generator to look up embeddings by index
```

### `remove_reply_syntax(content)`
(No comment above it in the source.)
