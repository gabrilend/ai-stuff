# 8-009: Project Cleanup and Organization

## Status
- **Phase**: 8
- **Priority**: Low
- **Type**: Maintenance/Cleanup

## Current Behavior

The project has accumulated temporary files, empty directories, and informal issue notes
that should be cleaned up:

1. **Empty directories**: `/libs/libs-2/` is empty (verified: contains only `.` and `..`)
2. **Misplaced files**: `/output5.pdf` (5.7MB) sits in project root instead of `/output/archive/`
3. **Temp extraction files**: `/temp/` contains 3 extraction directories (~688MB total):
   - `extract-1765687766` (17MB)
   - `extract-1765688017` (16MB)
   - `extract-1765764577` (655MB)
4. **Orphaned assets**: `/assets/assets-2/` contains single file `enhanced-project-file-server.html`
5. **Informal issue notes**: Two issue files lack proper formatting:
   - `notes-lack-names-in-generated-html.md` - needs `{PHASE}{ID}-{DESCR}` naming
   - `fediverse-boosts-are-links-and-not-text` - missing `.md` extension, needs formatting

## Intended Behavior

- All temporary extraction directories removed (after verification)
- Empty directories removed
- Misplaced files moved to appropriate locations
- All issue files follow proper naming convention and structure
- Project root is clean and organized
- ~700MB disk space recovered

## Suggested Implementation Steps

1. [x] Verify each file/directory state before modifying
2. [x] Delete empty `/libs/libs-2/` directory
3. [x] Move `/output5.pdf` to `/output/archive/`
4. [x] Verify media files exist in `/input/media_attachments/` before deleting temp
5. [x] Remove temp extraction directories (~688MB freed)
6. [x] Handle `/assets/assets-2/` - migrated to shared utility location
7. [x] Reformat `notes-lack-names-in-generated-html.md` as `8-006-fix-note-filenames-in-html.md`
8. [x] Reformat `fediverse-boosts-are-links-and-not-text` as `8-007-scrape-fediverse-boost-content.md`
9. [x] Update phase-8-progress.md
10. [x] Commit changes

## Related Documents

- `/docs/table-of-contents.md`
- `/issues/phase-8-progress.md`

## Implementation Log

### Session: 2025-12-17

**Verification Results:**
- `/libs/libs-2/`: CONFIRMED EMPTY (only `.` and `..`)
- `/output5.pdf`: CONFIRMED EXISTS (5.7MB, dated Sep 23)
- `/temp/`: CONFIRMED 3 directories (~688MB total)
- `/assets/assets-2/`: Contains `enhanced-project-file-server.html` (83KB)
- `/output/archive/`: EXISTS, has `generated-site/` and `test-outputs/` subdirs
- Informal issues: Both exist and need reformatting

**Actions Taken:**
1. Deleted empty `/libs/libs-2/` directory
2. Moved `/output5.pdf` to `/output/archive/output5.pdf`
3. Verified media files in `/input/media_attachments/` (546 files) before deleting temp
4. Removed temp extraction directories: ~688MB freed
5. Migrated file server utility to shared location:
   - Library: `/home/ritz/programming/ai-stuff/scripts/libs/project-file-server.lua`
   - Runner: `/home/ritz/programming/ai-stuff/scripts/project-file-server`
   - Updated issue 2-015 reference
6. Created properly formatted issue files:
   - `8-006-fix-note-filenames-in-html.md`
   - `8-007-scrape-fediverse-boost-content.md`
7. Removed old informal issue files

**Space Recovered:** ~693MB (688MB temp + 5MB PDF from root)

---
