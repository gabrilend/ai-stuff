# scrape-boost-content.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/scrape-boost-content.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Boost Content Scraper
====================
This script fetches the actual content of external fediverse boost URIs.
It respects rate limits (1 second between requests, 2 seconds for same domain)
and caches results to avoid re-scraping. Output is saved to assets/boost-content-cache.json
for use by extract-fediverse.lua during poem extraction.

Usage:
  lua scripts/scrape-boost-content.lua [--dir PATH] [--force]

The --force flag will re-scrape URIs even if they are already cached.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `read_json_file(path)`
(No comment above it in the source.)

### `write_json_file(path, data)`
(No comment above it in the source.)

### `extract_domain(uri)`
(No comment above it in the source.)

### `sleep(seconds)`
(No comment above it in the source.)

### `fetch_activitypub_json(uri)`
(No comment above it in the source.)

### `extract_content_from_activitypub(ap_data)`
(No comment above it in the source.)

### `load_cache()`
(No comment above it in the source.)

### `save_cache(cache)`
(No comment above it in the source.)

### `get_external_boost_uris()`
(No comment above it in the source.)

### `scrape_boosts()`
(No comment above it in the source.)
