# 501: Implement Version Tracking

## Status
- [ ] Not started

## Current Behavior

No version tracking exists.

## Intended Behavior

A local database/file that:
- Records uploaded work IDs and URLs
- Tracks upload timestamps
- Stores project-to-work mappings
- Enables "update existing" vs "create new" decisions
- Maintains history of all uploads

## Suggested Implementation Steps

1. Create src/version-tracker.lua
2. Design local state file format (JSON or lua table)
3. Implement state file read/write
4. Add function to check if project was previously uploaded
5. Add function to get previous work ID for updates
6. Store git commit hash with each upload for diff detection

## State File Example

```lua
{
    ["world-edit-to-execute"] = {
        work_id = "12345678",
        work_url = "https://archiveofourown.org/works/12345678",
        last_upload = "2024-12-29T15:30:00Z",
        last_commit = "abc123def456",
        chapters = {
            ["overview"] = { chapter_id = "1", title = "Overview" },
            ["src/main.lua"] = { chapter_id = "2", title = "Main Entry Point" },
            -- ...
        }
    }
}
```

## Related Documents

- 402-implement-work-creation.md
- 403-implement-chapter-upload.md

## Notes

This is the memory of what's been done. Essential for updates vs recreation.
