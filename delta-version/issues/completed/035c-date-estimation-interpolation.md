# Issue 035c: Date Estimation and Interpolation

## Parent Issue
- **Issue 035**: Project History Reconstruction from Issue Files

## Current Behavior (Before Implementation)

The `reconstruct-history.sh` script created commits without dates - all commits used the current time regardless of when the issues were actually completed.

This meant:
- Git history didn't reflect actual development timeline
- Commits appeared to all happen at the same time
- Historical context was lost

## Implemented Behavior

Added date estimation with multiple sources and interpolation to create realistic commit dates.

### New Functions

1. **`extract_explicit_date()`**: Parses dates from issue content
   - Patterns: `Completed: 2024-12-15`, `**Completed**: 2024-12-15`, etc.
   - Returns epoch timestamp

2. **`get_file_mtime()`**: Gets file modification time via `stat -c %Y`

3. **`estimate_issue_date()`**: Primary date estimation function
   - Tries explicit date first
   - Falls back to file mtime
   - Last resort: current time

4. **`interpolate_dates()`**: Ensures chronological ordering
   - If date would be before previous, adds 1 hour to previous
   - Applies sanity checks (no future dates, no dates before 2020)
   - Outputs date source for logging

5. **`format_epoch_for_git()`**: Formats epoch for git's `--date` option

6. **`get_vision_date()`**: Estimates date for vision file

### Date Source Priority

| Priority | Source | Reliability |
|----------|--------|-------------|
| 1 | Explicit date in issue | High |
| 2 | File modification time | Medium |
| 3 | Interpolation from adjacent | Medium |
| 4 | Current time | Low |

### Sanity Checks

- **No future dates**: Clamped to current time
- **No ancient dates**: Clamped to 2020-01-01 minimum
- **Chronological order**: Interpolated if out of sequence

### Output

Dry-run now shows date sources:
```
[2] 004-extract-project-histories @ 2025-12-07 [mtime]
[3] 006-initialize-master-branch @ 2025-12-07 [mtime]
[4] 007-remote-repository-setup @ 2025-12-07 [mtime]
[5] 012-generate-unified-gitignore @ 2025-12-07 [interpolated]
```

Commits use GIT_AUTHOR_DATE and GIT_COMMITTER_DATE environment variables.

## Files Changed

- `delta-version/scripts/reconstruct-history.sh`:
  - Added date estimation section (035c)
  - Updated `create_vision_commit()` with optional date parameter
  - Updated `create_issue_commit()` with optional date parameter
  - Updated `reconstruct_history()` to estimate and use dates
  - Updated `dry_run_report()` to show estimated dates and sources

## Testing

Tested with dry-run on delta-version project:
```bash
./reconstruct-history.sh --dry-run --verbose /path/to/delta-version
```

Shows dates for each issue with source indicators (explicit/mtime/interpolated).

## Related Documents
- **Issue 035**: Parent issue for project history reconstruction
- **Issue 035a**: Project detection and external import (completed)
- **Issue 035b**: Dependency graph and topological sort (completed)
- **Issue 035d**: File-to-issue association heuristics (next)

## Metadata
- **Priority**: High (part of 035)
- **Complexity**: Medium
- **Dependencies**: Issue 035a, 035b
- **Blocks**: Issue 035d, 035e
- **Completed**: 2025-12-17

## Success Criteria

- [x] `extract_explicit_date()` parses dates from issue content
- [x] `get_file_mtime()` retrieves file modification time
- [x] `estimate_issue_date()` combines sources with fallback chain
- [x] `interpolate_dates()` ensures chronological ordering
- [x] Sanity checks prevent future and ancient dates
- [x] `format_epoch_for_git()` formats dates for git commit
- [x] Vision commit uses estimated date
- [x] Issue commits use estimated dates
- [x] Dry-run shows dates and sources
- [x] GIT_AUTHOR_DATE and GIT_COMMITTER_DATE set correctly
