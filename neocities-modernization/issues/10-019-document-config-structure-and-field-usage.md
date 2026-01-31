# Issue 10-019: Document Config Structure and Field Usage

**Priority**: Low
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30

---

## Current Behavior

The `config.lua` file contains significant "data-as-code" with minimal documentation about:
- When to use which fields
- What values are valid for each field
- Which fields are required vs optional
- How fields interact with each other

Example of underdocumented structure:
```lua
sources = {
    fediverse = {
        enabled = true,           -- What happens if false?
        format = "activitypub",   -- What formats are valid?
        directories = {
            {
                name = "primary",       -- Is "primary" special? Required?
                path = "input/fediverse",
                description = "...",    -- Optional? Used where?
                optional = true         -- What's the difference?
            },
        },
        media = {                 -- When is this section needed?
            extract_attachments = true,
            output_path = "..."
        },
    },
}
```

Users (and future developers) have to read source code to understand what these fields do.

---

## Intended Behavior

### 1. Inline Documentation in `config.lua`

Each section should have a brief header explaining its purpose, and fields should have concise inline comments when their meaning isn't obvious:

```lua
-- {{{ sources
-- Unified input source configuration.
-- Each source type has: enabled, format, directories, and optional media settings.
--
-- Field reference:
--   enabled       - (bool) Skip this source entirely if false
--   format        - (string) Parser to use: "activitypub", "atproto", "plaintext", "messages_export"
--   directories   - (array) One or more input directories to scan
--     .name       - (string) Human-readable identifier for logging/debugging
--     .path       - (string) Relative to project root, or absolute path
--     .optional   - (bool) If true, missing directory is a warning not an error
--     .description- (string) Optional note for documentation purposes
--   media         - (table) Only for sources that extract media attachments
--     .extract_attachments - (bool) Whether to copy media files during extraction
--     .output_path         - (string) Where to store extracted media
sources = { ... }
```

### 2. Reference Document in `docs/`

Create `docs/config-reference.md` with:

- **Overview**: Purpose of config.lua, how it's loaded
- **Section-by-section guide**: What each section does, when you'd modify it
- **Field tables**: For complex sections like `sources`, `external_files`
- **Examples**: Common customizations (adding a new source, changing paths)
- **Validation**: What errors you'll see if config is wrong

Variable verbosity:
- Simple sections (like `layout`) need just a sentence
- Complex sections (like `sources`, `external_files`) need detailed field tables
- Rarely-changed sections (like `semantic_colors`) need minimal explanation

---

## Suggested Implementation Steps

### Phase 1: Audit Current Documentation
1. [ ] Read through config.lua and note underdocumented fields
2. [ ] Identify which fields are actually used by which scripts
3. [ ] Note any fields that appear unused or deprecated

### Phase 2: Inline Config Comments
1. [ ] Add field reference block to `sources` section header
2. [ ] Add field reference block to `external_files` section header
3. [ ] Add brief explanations to any non-obvious fields in other sections
4. [ ] Keep comments concise - details go in docs/

### Phase 3: Reference Document
1. [ ] Create `docs/config-reference.md`
2. [ ] Write overview section (loading, location, format)
3. [ ] Document each section with appropriate verbosity:
   - **Heavy docs**: sources, external_files, extraction
   - **Medium docs**: layout, pagination, semantic_colors
   - **Light docs**: asset_paths, privacy, embedding_settings
4. [ ] Add examples for common customization tasks
5. [ ] Add "Which scripts use this?" notes for key sections

### Phase 4: Cross-Reference
1. [ ] Update `docs/table-of-contents.md` to include new document
2. [ ] Add "See docs/config-reference.md for details" note in config.lua header

---

## Documentation Priorities

Sections by need for documentation:

| Section | Priority | Reason |
|---------|----------|--------|
| `sources` | High | Complex nested structure, multiple formats, optional/required interplay |
| `external_files` | High | Array of objects, destination path conventions |
| `extraction` | Medium | Boolean flags, ignored_archives list |
| `excluded_poems` | Medium | ID format varies by source type |
| `layout` | Low | Numbers are self-explanatory from names |
| `semantic_colors` | Low | Just CSS classes |
| `pagination` | Low | Simple numeric settings |

---

## Example Content for `docs/config-reference.md`

```markdown
# Config Reference

## Overview

All configuration lives in `config.lua` at the project root. It uses Lua table
syntax and is loaded via `libs/config-loader.lua`.

## sources

Defines where poem content comes from. Each source type has its own parser.

### Supported Formats

| Format | Parser | Source |
|--------|--------|--------|
| `activitypub` | Mastodon outbox.json | Fediverse archives |
| `atproto` | Bluesky CAR files | Bluesky exports |
| `plaintext` | .txt/.md files | Notes directory |
| `messages_export` | export.json | Matrix exports |

### Directory Options

```lua
{
    name = "backup-2024",     -- For logs: "Processing backup-2024..."
    path = "/home/user/old",  -- Absolute or relative to project root
    optional = true,          -- Missing = warning, not error
    description = "..."       -- Your notes, unused by code
}
```

### When to Use `optional = true`

- External backup directories that may not always be mounted
- Secondary archives you're testing before making permanent
- User-specific paths that vary between machines

...
```

---

## Related Documents

- `/config.lua` - The configuration file itself
- `/libs/config-loader.lua` - How config is loaded
- `/libs/sources-loader.lua` - How sources are parsed
- `/docs/table-of-contents.md` - Documentation index

---

## Notes

- Focus on "when to use" over "what it does" - the latter is often obvious
- Include examples of common mistakes and their error messages
- Consider adding a `--validate-config` flag to run.sh for pre-flight checks
- The TUI config editor (10-013) could benefit from this documentation as tooltips

---

## Design Review: Simplification Opportunities

While documenting, consider whether some fields are even necessary. The code could infer sensible defaults:

### Fields That Could Be Optional/Inferred

| Field | Current State | Could Be Inferred |
|-------|---------------|-------------------|
| `name` | Required for logging | Default to directory basename, or `"source-1"`, `"source-2"` |
| `format` | Required per source | Could be detected from file structure (outbox.json → activitypub) |
| `enabled` | Required, defaults to true | Could default to true, only specify when disabling |
| `description` | Optional | Keep optional, purely for human notes |

### What Does "Primary" Even Mean?

Currently `name = "primary"` is just a string - it has no special behavior. The code doesn't treat it differently. When documenting, we should either:
1. **Define it**: "The first directory listed is treated as primary for deduplication priority"
2. **Remove the concept**: Just document that directories are processed in order

### Possible Simplifications

**Current (verbose):**
```lua
sources = {
    notes = {
        enabled = true,
        format = "plaintext",
        directories = {
            { name = "primary", path = "input/notes" }
        }
    }
}
```

**Could become (minimal):**
```lua
sources = {
    notes = "input/notes"  -- Single path, format auto-detected
}
```

**Or with multiple directories:**
```lua
sources = {
    notes = {
        "input/notes",
        "/home/user/backup/notes"  -- Second is optional by default
    }
}
```

### Recommendation

During documentation, note which fields are:
1. **Truly required** - Must be specified, no sensible default
2. **Required but could be inferred** - Candidate for future simplification
3. **Already optional** - Document the default behavior
4. **Cosmetic** - Only for human readability (name, description)

This creates a roadmap for a potential 10-020 issue to simplify config ergonomics.

