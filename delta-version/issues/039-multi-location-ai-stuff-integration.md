# Issue #039: Multi-Location ai-stuff Directory Integration

## Current Behavior
The `reconstruct-history.sh` script and `list-projects.sh` only scan a single hardcoded location for projects. There may be multiple `ai-stuff` directories across different drives or locations that contain projects needing history reconstruction.

## Intended Behavior
Implement a discovery and integration system that:
1. Searches for all directories named `ai-stuff` across the filesystem
2. Runs the history importer on discovered project directories
3. Handles "excluded" projects that should not be pushed to public GitHub
4. Maintains projects at their current locations with symlinks for unified access

## Implementation Details

### Discovery Phase
```bash
# Find all ai-stuff directories
find /mnt /home -type d -name "ai-stuff" 2>/dev/null
```

### Exclusion List
Some projects should be marked as "local-only" and excluded from public GitHub:
- Projects containing adult/mature content
- Projects with licensing restrictions
- Projects with sensitive/personal data

Create an exclusion config file:
```
# ~/.config/reconstruct-history/excluded-projects.txt
# Projects listed here will be reconstructed but NOT pushed to public repos
# They remain at their current locations with symlinks for local access
project-name-1
project-name-2
```

### Symlink Integration (Bidirectional)
For excluded projects that should remain at their current locations, create two-way navigation:

**From main to frontier:**
```bash
# Create symlink in main ai-stuff directory pointing to distant project
ln -s /path/to/excluded/project /mnt/mtwo/programming/ai-stuff/the-frontier/project-name
```

**From frontier to main:**
```bash
# Create symlink in distant project pointing back to main ai-stuff
mkdir -p /path/to/excluded/project/busy-streets
ln -s /mnt/mtwo/programming/ai-stuff /path/to/excluded/project/busy-streets/ai-stuff
```

The `the-frontier/` subdirectory houses projects at the edge of the main repository - visible locally but not pushed to remote. The distinctive name prevents conflicts with system `.local` conventions and makes the separation explicit.

The `busy-streets/` directory in frontier projects provides a path back to civilization - the main ai-stuff hub where all the activity happens. This bidirectional linking ensures you can navigate freely between the frontier and the main streets without losing your way.

### Suggested Implementation Steps
1. Add `--discover` flag to find all ai-stuff directories
2. Create exclusion list config file format
3. Add `--exclude-list <file>` option to respect exclusions
4. Implement bidirectional symlink creation:
   - `the-frontier/` in main → distant projects
   - `busy-streets/` in distant → main ai-stuff
5. Update `--scan` to show exclusion status
6. Add warning before any push operations for excluded projects
7. Add `.gitignore` entries for both `the-frontier/` and `busy-streets/`

## Related Documents
- Issue #035: Project History Reconstruction
- `scripts/reconstruct-history.sh`
- `scripts/list-projects.sh`

## Notes
- The exclusion mechanism protects against accidental public exposure
- Bidirectional symlinks allow unified local development while maintaining separation
- Add `.gitignore` patterns for both `the-frontier/` and `busy-streets/` directories
- "The sword of Damocles" - platform ban risk for certain content types
- "The frontier" - where projects roam free, beyond the reach of remote pushes
- "Busy streets" - the path back to the main hub, where all the action is

## Priority
Medium - Quality of life improvement for multi-drive setups
