# Issue 9-005: URL Switching Helper Script

## Current Behavior

HTML generation uses hardcoded local file:// paths for testing:
```
file:///home/ritz/programming/ai-stuff/neocities-modernization/output/similar/0001-01.html
file:///home/ritz/programming/ai-stuff/neocities-modernization/output/chronological-01.html
```

These paths work for local browser testing but won't work when deployed to neocities.

## Intended Behavior

A helper script that converts all links in generated HTML files from local testing paths to production paths:

**Local (testing):**
```
file:///home/ritz/programming/ai-stuff/neocities-modernization/output
```

**Production (neocities):**
```
/similar-different
```

The script should:
1. Recursively find all HTML files in the output directory
2. Replace all occurrences of the local base path with the production base path
3. Be idempotent (running twice shouldn't break anything)
4. Optionally support reverse conversion (production → local) for debugging
5. Skip the self-hosted source browser tree (`output/source/`, Issue 10-052).
   Those pages render the project's own code, which legitimately contains the
   base-path strings as displayed DATA, not as deployable links. A context-blind
   substring replace would rewrite the code listings and make the viewer
   misrepresent the source. The source browser's own navigation is entirely
   relative, so it never needs conversion — excluding the subtree is both safe
   and correct.

## Suggested Implementation Steps

1. Create `scripts/convert-urls.sh` or `scripts/convert-urls.lua`
2. Accept parameters:
   - `--to-production` or `-p`: Convert local → production
   - `--to-local` or `-l`: Convert production → local (optional)
   - `--dry-run`: Show what would be changed without modifying files
3. Use `sed` or Lua string replacement to update all href attributes
4. Print summary of files modified and links changed

## Example Usage

```bash
# Convert to production before deploying
./scripts/convert-urls.sh --to-production

# Convert back to local for testing
./scripts/convert-urls.sh --to-local

# Preview changes without modifying
./scripts/convert-urls.sh --to-production --dry-run
```

## Configuration

The script should define these constants at the top:
```lua
local LOCAL_BASE = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
local PRODUCTION_BASE = "/similar-different"
local OUTPUT_DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization/output"
local EXCLUDE_DIRS = { "source" }  -- subtrees skipped: code-as-data, not links
```

`EXCLUDE_DIRS` is rendered into a `find` prune clause so the converter never
descends into those subtrees, and the run header prints a `Skip:` line so the
exclusion is visible rather than silent.

## Related Documents

- Issue 9-003: HTML Rendering and Performance Fixes (added absolute paths)

## Priority

Medium - Required before first production deployment to neocities.

## Notes

- The local path uses `/home/ritz/...` which may be a symlink to `/mnt/mtwo/...`
- Production path is relative to neocities root, so `/similar-different` works for `ritz-menardi.neocities.org/similar-different/`
- Consider adding this as a step in the deployment workflow

## Implementation Notes

### Completed ✓

Script created at `scripts/convert-urls` with the following features:

**CLI Options:**
- `-p, --to-production`: Convert local file:// URLs to /similar-different/
- `-l, --to-local`: Convert /similar-different/ URLs back to file://
- `-d, --dry-run`: Preview changes without modifying files
- `-v, --verbose`: Show detailed per-file progress
- `--dir PATH`: Override output directory

**Behavior:**
- Uses plain text search (not regex) for reliable URL matching
- Idempotent: running twice has no additional effect
- Scans recursively for all .html files in output directory
- Reports summary with file count and total URL replacements

**Test Results (15,698 HTML files):**
- Dry-run to-production: Would modify 15,695 files, 9,474,949 URLs
- Dry-run to-local (when already local): 0 modifications (idempotent ✓)

**Usage Example:**
```bash
# Before deploying to neocities
./scripts/convert-urls --to-production

# After testing locally, convert back
./scripts/convert-urls --to-local
```
