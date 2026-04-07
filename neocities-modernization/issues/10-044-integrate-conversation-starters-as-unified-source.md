# Issue 10-044: Integrate Conversation-Starters as Unified Source

## Current Behavior

The project has no integration with the "conversation-starters" backup archive located at `/home/ritz/backups/conversation-starters/`. This archive is an encrypted ZIP containing a curated collection of creative content:

**Contents (from backup script):**
```
~/words/                              - Text content (poems, notes)
~/pictures/poem-pictures/             - Already in project (duplicate OK)
~/pictures/my-art/                    - Already in project (duplicate OK)
~/pictures/adventure-time-wallpapers/ - NOT yet integrated
~/pictures/things-i-almost-posted/    - Already in project (duplicate OK)
~/pictures/pictures-of-zelda          - NOT yet integrated
~/documents/algorism/                 - Documents (new content type)
~/music/my-music/*.wav                - Music files (new content type)
```

## Intended Behavior

"conversation-starters" should be treated as a **single unified source** that displays all its content together in similar/different navigation and the gallery. This creates a "best of" collection that represents the user's conversation-starting content.

### Key Requirements

1. **Unified Source Identity**: All content from conversation-starters appears as `conversation-starters/XXXX` in poem_index, not as separate categories

2. **Multi-Media Support**:
   - Images display in gallery and similar/different pages (like existing sources)
   - Music files display as playable audio elements with HTML5 `<audio>` tags
   - Documents (algorism) may need special handling or embedding

3. **Duplicate Tolerance**: Items that also exist in my-art, poem-pictures, etc. are intentionally shown twice - once from each source. This is desired behavior.

4. **Similar/Different Navigation**: Content should participate in similarity rankings based on:
   - Images: filename-based embeddings (like Issue 10-042c)
   - Music: filename-based embeddings (same approach)
   - Documents: content-based embeddings (extract text)

## Technical Considerations

### ZIP Extraction
The conversation-starters archive is encrypted and split:
```
/home/ritz/backups/conversation-starters/zip-files/conversation-starts.zip
/home/ritz/backups/conversation-starters/zip-files/conversation-starts.z01
... (multiple parts)
```

Need to:
1. Reassemble split archive
2. Decrypt with user-provided password
3. Extract to `input/conversation-starters/`

### Audio Player Integration
Music files (`.wav`) need HTML audio player support:
```html
<audio controls>
  <source src="path/to/file.wav" type="audio/wav">
</audio>
```

This is a new content type for the HTML generator.

### Embedding Strategy
For similar/different to work:
- **Images**: Extract display name from filename → embed
- **Music**: Extract display name from filename → embed
- **Documents**: Extract text content → embed

## Suggested Implementation Steps

### Phase 1: Archive Extraction
1. Add conversation-starters to config.lua sources with archive entry
2. Implement encrypted ZIP extraction (may need `unzip -P` or user prompt)
3. Create `input/conversation-starters/` with extracted content

### Phase 2: Image Integration
1. Add conversation-starters as image source in config.lua sources.images
2. Run image-manager to catalog images
3. Add to gallery pages
4. Verify similar/different integration via filename embeddings

### Phase 3: Audio Integration
1. Add audio file type support to image-manager (or create audio-manager)
2. Update HTML generators to render `<audio>` tags for music files
3. Create audio player styling that matches dark theme

### Phase 4: Document Integration
1. Add document extraction to poem-extractor (or create doc-extractor)
2. Generate embeddings from document text content
3. Display in similar/different with appropriate formatting

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `config.lua` | MODIFY | Add conversation-starters source with archive entry |
| `src/audio-manager.lua` | CREATE | Catalog and manage audio files |
| `src/flat-html-generator.lua` | MODIFY | Add audio player rendering |
| `scripts/extract-conversation-starters.lua` | CREATE | Handle encrypted ZIP extraction |

## Dependencies

- Issue 10-042c: Filename embeddings (needed for image/audio similarity)
- User must provide ZIP password for extraction

## Related Documents

- `/home/ritz/backups/conversation-starters/conversation-starters` - Backup script showing content
- `/home/ritz/backups/conversation-starters/zip-files/` - Split encrypted archives

## Acceptance Criteria

- [ ] Conversation-starters content extracted to input/conversation-starters/
- [ ] Images appear in gallery as "Conversation Starters" collection
- [ ] Music files playable via HTML5 audio controls
- [ ] All content participates in similar/different navigation
- [ ] Content shows as `conversation-starters/XXXX` source
- [ ] Duplicates intentionally shown (from both original and conversation-starters)

---

**Status**: OPEN

**Priority**: Medium

**Phase**: 10 (Developer Experience & Tooling)

**Estimated Effort**: High (new content type support, encryption handling)

**Created**: 2026-04-06
