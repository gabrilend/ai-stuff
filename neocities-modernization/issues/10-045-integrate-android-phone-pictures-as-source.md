# Issue 10-045: Integrate Android Phone Pictures as Source

## Current Behavior

The project has no integration with pictures stored on the user's Android phone. These are a valuable source of personal media that should be included in the gallery and similar/different navigation.

## Intended Behavior

Pictures from the Android phone should be:
1. Synced to a local directory (likely via rmail or similar transfer mechanism)
2. Registered as an image source in config.lua
3. Displayed in the gallery as "Phone Pictures" (or similar)
4. Participating in similar/different navigation via filename embeddings

## Technical Approach

### Transfer Mechanism
- **rmail** (or alternative to be determined)
- User will walk through the setup process
- May need periodic sync script or manual trigger

### Source Configuration
```lua
-- In config.lua sources.images.directories:
{
    name = "android-phone",
    path = "input/media_attachments/phone-pictures",
    description = "Pictures from Android phone",
    optional = true,
    external = {
        source = "TBD",  -- rmail endpoint or local mount point
    },
    -- randomize_order may be needed if timestamps aren't meaningful
},
```

### Directory Structure
```
input/media_attachments/phone-pictures/
├── DCIM/          -- Camera photos
├── Screenshots/   -- Screenshots
├── Downloads/     -- Downloaded images
└── ...            -- Other Android media folders
```

## Suggested Implementation Steps

1. **User walkthrough**: Understand rmail setup and transfer flow
2. **Create sync script**: `scripts/sync-phone-pictures.sh` (or .lua)
3. **Add to config.lua**: Register as image source
4. **Test sync**: Verify pictures transfer correctly
5. **Run image-manager**: Catalog new images
6. **Regenerate gallery**: Include phone-pictures in gallery pages
7. **Generate filename embeddings**: For similar/different (depends on 10-042c)

## Questions to Resolve

- [ ] What is the rmail endpoint/configuration?
- [ ] Which phone directories should be included?
- [ ] Should we preserve phone directory structure or flatten?
- [ ] Are there any privacy/filtering considerations (e.g., skip certain folders)?
- [ ] What's the expected image count?
- [ ] Should timestamps be preserved for chronological integration?

## Dependencies

- Issue 10-042c: Filename embeddings for similar/different (optional but enhances integration)
- rmail or alternative transfer tool setup

## Related Issues

- Issue 10-044: Conversation-starters integration (similar multi-source pattern)
- Issue 10-042a: Gallery pages (phone pictures will appear here)

## Acceptance Criteria

- [ ] Sync mechanism established (rmail or alternative)
- [ ] Pictures sync from phone to `input/media_attachments/phone-pictures/`
- [ ] Source registered in config.lua
- [ ] Images appear in gallery as "Phone Pictures" collection
- [ ] Images participate in similar/different navigation
- [ ] Sync can be triggered manually or on schedule

---

**Status**: OPEN - Awaiting user walkthrough for rmail setup

**Priority**: Low

**Phase**: 10 (Developer Experience & Tooling)

**Estimated Effort**: Medium (depends on rmail complexity)

**Created**: 2026-04-06
