# extract-fediverse.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/extract-fediverse.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Fediverse content extraction script
Parses ActivityPub JSON and extracts formatted posts with attachment metadata

ACTIVITYPUB ATTACHMENT FORMAT (Mastodon/W3C Standard):
Each Note object in outbox.json may contain an "attachment" array:
{
  "type": "Create",
  "object": {
    "type": "Note",
    "content": "<p>Post text here</p>",
    "attachment": [
      {
        "type": "Document",
        "mediaType": "image/png",           -- MIME type (image/png, image/jpeg, video/mp4, etc.)
        "url": "https://server.com/media/files/123/456/789/original/abc123.png",
        "name": "Alt text description",     -- User-provided alt text (may be null)
        "blurhash": "LEHV6nWB2yk8...",      -- Blur hash for placeholder (optional)
        "width": 1920,                      -- Image dimensions (optional)
        "height": 1080
      }
    ]
  }
}

URL PATH MAPPING:
The URL path structure maps directly to local media_attachments directory:
  URL:   https://tech.lgbt/media/files/113/464/378/730/595/557/original/658cbf8cc6804a09.png
  Local: input/media_attachments/files/113/464/378/730/595/557/original/658cbf8cc6804a09.png

The numeric segments (113/464/378/...) are derived from Mastodon's internal attachment ID
split into 3-digit chunks for filesystem distribution.
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `parse_args(args)`

```
Parse command line arguments for DIR, source override, and boost inclusion
```

### `relative_path(absolute_path)`

```
Issue 7-003: Show project name instead of "./" when path equals DIR
```

### `get_include_boosts()`
(No comment above it in the source.)

### `load_boost_content_cache()`
(No comment above it in the source.)

### `privacy(key)`

```
every value from config.lua's privacy section; a missing one is an error
(Issue 10-071). `x or true` cannot express a setting: it turned a
configured false into true.
```

### `normalize_username(username)`
(No comment above it in the source.)

### `anonymize_mention(username, server)`
(No comment above it in the source.)

### `process_mentions_for_privacy(content, privacy_mode)`
(No comment above it in the source.)

### `categorize_activity(activity)`
(No comment above it in the source.)

### `extract_boost_content(announce_activity)`
(No comment above it in the source.)

### `process_fediverse_content(raw_content, cw, privacy_mode)`
(No comment above it in the source.)

### `extract_date(timestamp)`
(No comment above it in the source.)

### `extract_full_date(timestamp)`
(No comment above it in the source.)

### `generate_poem_metadata(content, cw, source_data, original_html)`
(No comment above it in the source.)

### `extract_attachments(content_object)`
(No comment above it in the source.)
