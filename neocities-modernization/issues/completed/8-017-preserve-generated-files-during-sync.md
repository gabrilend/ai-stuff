# Issue 8-017: Preserve Generated Files During Input Sync

## Current Behavior

The `scripts/update-words` script calls `/home/ritz/backups/words/sync-to-projects`, which does:

```bash
rm -rf "${NEOCITIES_DIR}/input"
mkdir -p "${NEOCITIES_DIR}/input"
rsync -av ${MSG_ZIP} ${FEDI_ZIP} ${NOTES_DIR} "${NEOCITIES_DIR}/input"
```

This **deletes the entire input directory** including generated files:
- `input/fediverse/files/poems.json`
- `input/messages/files/poems.json`
- `input/notes/files/poems.json`

When `scripts/update` then runs its freshness check, the output files don't exist, causing
full re-extraction every time run.sh executes (~2-3 minutes of unnecessary work).

### The Deletion Loop

1. `run.sh` calls `update-words`
2. `update-words` calls `sync-to-projects`
3. `sync-to-projects` does `rm -rf input/` (deletes poems.json files)
4. `scripts/update` checks: "Do poems.json files exist?" → No!
5. Full extraction runs, recreates poems.json (~2-3 min)
6. Next run, step 3 deletes them again...

---

## Intended Behavior

Generated files should be preserved across sync operations. The freshness check in
`scripts/update` should work correctly, skipping extraction when source ZIPs haven't changed.

---

## Suggested Implementation Steps

### Option A: Preserve in update-words (Recommended)

Modify `scripts/update-words` to back up and restore generated files:

```bash
#!/bin/bash
set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
BACKUP_DIR="${DIR}/temp/preserved-files"

# Preserve generated files before sync
preserve_generated_files() {
    mkdir -p "${BACKUP_DIR}"
    for subdir in fediverse messages notes; do
        if [ -d "${DIR}/input/${subdir}/files" ]; then
            mkdir -p "${BACKUP_DIR}/${subdir}"
            cp -a "${DIR}/input/${subdir}/files" "${BACKUP_DIR}/${subdir}/"
        fi
    done
}

# Restore generated files after sync
restore_generated_files() {
    for subdir in fediverse messages notes; do
        if [ -d "${BACKUP_DIR}/${subdir}/files" ]; then
            mkdir -p "${DIR}/input/${subdir}"
            cp -a "${BACKUP_DIR}/${subdir}/files" "${DIR}/input/${subdir}/"
        fi
    done
    rm -rf "${BACKUP_DIR}"
}

# Run with preservation
preserve_generated_files
/home/ritz/backups/words/sync-to-projects > /dev/null 2>&1
restore_generated_files

# Remove unwanted ZIP files
rm -f "${DIR}/input/images/poem-pictures/neocities-ritz-menardi.zip"
```

### Option B: Use Content Checksums

Store SHA256 checksums of ZIP files in a manifest. Only extract if checksums change:

```bash
MANIFEST="${DIR}/assets/extraction-manifest.json"
# Contains: {"most-recent-29.zip": "abc123...", "similar-different.zip": "def456..."}
```

### Option C: Modify External Script (Requires coordination)

Modify `sync-to-projects` to use rsync without deleting the entire directory:

```bash
# Instead of: rm -rf input && mkdir -p input && rsync ...
# Use: rsync -av --delete --exclude='*/files/' ...
```

---

## Impact

- **Before fix**: Full extraction every run (~2-3 minutes)
- **After fix**: Extraction only when ZIPs actually change (~5 seconds skip check)

---

## Related Files

- `scripts/update-words` - Entry point for sync (in project)
- `/home/ritz/backups/words/sync-to-projects` - External sync script
- `scripts/update` - Has freshness check that fails due to deleted files
- `input/*/files/poems.json` - Generated files being deleted

---

## Implementation (2025-12-23)

Implemented Option A: Modified `scripts/update-words` to preserve and restore generated files.

**Test results:**
```
=== Running update-words ===
   💾 Preserved 3 generated file directories
   ♻️  Restored 3 generated file directories

=== Running scripts/update (should skip) ===
✅ Extraction data is up to date, skipping ZIP extraction
```

File timestamps are preserved across sync, freshness check works correctly.

---

## Document History

- **Created**: 2025-12-23
- **Implemented**: 2025-12-23
- **Status**: Completed
- **Phase**: 8
- **Priority**: High (affects every run.sh execution)
