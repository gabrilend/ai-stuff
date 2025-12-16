# Issue 004: Extract Project Histories

## Current Behavior

Multiple projects contain their own git repositories with valuable commit history:
- **adroit/**: Character system project with 1 commit (d0a0ec8)
- **progress-ii/**: Terminal game with 2 commits (c121808, b5f489d)
- **progress-ii/game-state/**: Nested game state repository with 1 commit (bf1b4ea)
- **risc-v-university/**: Educational project with 5+ commits, active development
- **magic-rumble/**: Game project with 1 commit (89ee180)
- **handheld-office/**: Office application with 4+ commits, active development

These histories are currently isolated and will be lost if projects are simply added to the main repository as untracked files.

## Intended Behavior

Extract and preserve all existing git commit histories from individual project repositories by:
1. Identifying all main project repositories (excluding library dependencies)
2. Creating temporary copies of each project's git history
3. Preparing history data for integration into main repository branches
4. Validating that no commit history is lost in the process
5. Handling nested repositories appropriately (like progress-ii/game-state)

## Suggested Implementation Steps

### 1. Identify Main Project Repositories
```bash
# Find project-level git repositories (not in libs/ or external dependencies)
find /home/ritz/programming/ai-stuff -name ".git" -type d | grep -v "/libs/" | grep -v "emsdk" | grep -v "rgbds"
```

### 2. Analyze Each Repository
For each main project repository:
- Record current branch and commit information
- List all branches and their commit counts
- Identify any tags or special references
- Check for uncommitted changes that need preservation

### 3. Extract Git History Data
```bash
# For each project:
# - Create git bundle for complete history
# - Extract commit logs and metadata
# - Preserve branch information
# - Handle any remote repository configurations
```

### 4. Handle Nested Repositories
Special handling for complex cases:
- **progress-ii/game-state/**: Nested repository within progress-ii
- Determine if nested repos should be separate branches or integrated
- Preserve relationships between parent and nested repositories

### 5. Validate History Preservation
- Verify all commits are accessible in extracted data
- Check that commit messages, timestamps, and author information are intact
- Ensure no data loss during extraction process

### 6. Prepare for Branch Integration
- Organize extracted histories by target branch name
- Resolve any naming conflicts between projects
- Prepare data structure for git subtree or filter-branch operations

## Implementation Details

### Project Repository Mapping
```
adroit/ → branch: adroit
progress-ii/ → branch: progress-ii  
progress-ii/game-state/ → branch: progress-ii-gamestate (or integrate into progress-ii)
risc-v-university/ → branch: risc-v-university
magic-rumble/ → branch: magic-rumble
handheld-office/ → branch: handheld-office
```

### History Extraction Method
Use git bundle or git archive to create portable copies:
```bash
cd project_dir
git bundle create ../project-history.bundle --all
```

### Nested Repository Strategy
For progress-ii/game-state:
- Option A: Separate branch (progress-ii-gamestate)
- Option B: Integrate into progress-ii branch with subdirectory
- Decision based on logical relationship and future development needs

## Related Documents
- `001-prepare-repository-structure.md` - Repository foundation
- `005-configure-branch-isolation.md` - Branch setup using extracted histories
- `006-initialize-master-branch.md` - Master branch with all projects

## Tools Required
- Git bundle creation and extraction
- Git log analysis and parsing
- Shell scripting for repository traversal
- Data validation utilities

## Metadata
- **Priority**: High
- **Complexity**: Medium-High
- **Estimated Time**: 1-1.5 hours
- **Dependencies**: Issue 001 (repository structure)
- **Impact**: Preservation of development history

## Success Criteria
- All project commit histories extracted and preserved
- No commit data loss during extraction
- History data ready for branch integration
- Nested repositories handled appropriately
- Clear mapping of projects to target branches
- Validation that extracted data is complete and usable