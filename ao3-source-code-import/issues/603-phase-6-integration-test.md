# 603: Phase 6 Integration Test

## Status
- [ ] Not started

## Current Behavior

No integration test exists.

## Intended Behavior

A complete end-to-end test that:
1. Reads world-edit-to-execute project
2. Generates HTML archive
3. Creates work metadata
4. (In dry-run) Shows what would be uploaded
5. (In live mode) Uploads to AO3
6. Verifies the upload by fetching the work

## Test Scenarios

1. **Dry Run Test**: Full pipeline except upload
2. **Small Project Test**: Create a minimal test project, archive it
3. **Self-Archive Test**: Archive ao3-source-code-import itself
4. **Update Test**: Modify project, run update workflow
5. **Rollback Test**: Simulate upload failure, verify rollback

## Suggested Implementation Steps

1. Create issues/completed/demos/phase-6-demo.lua
2. Implement dry-run full pipeline
3. Create minimal test project in tmp/
4. Test archive generation
5. Manual verification of HTML output
6. Live upload test (with throwaway work)
7. Document results

## Success Criteria

- Pipeline completes without error
- Generated HTML is valid and readable
- Work appears on AO3 with correct metadata
- Chapters contain formatted source code
- Transcripts included as final chapters

## Related Documents

- All previous issues
- 601-build-main-cli.md
- 602-create-run-script.md

## Notes

This is the proof it works. The demo that shows the archive existing on AO3.
