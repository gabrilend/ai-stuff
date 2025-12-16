# Issue 005: Configure Branch Isolation

## Status: PARTIALLY COMPLETE

**Completed (2024-12-15):**
- Project branches created: adroit, handheld-office, magic-rumble, progress-ii, risc-v-university
- Each branch contains preserved git history from original project repositories
- Branches pushed to GitHub remote

**Optional/Future:**
- Sparse-checkout configuration (allows showing only relevant files when checking out a branch)
- This is not strictly required since each branch already contains only that project's history

## Original Description

The main repository will contain all projects in the master branch, but there is no mechanism for project-specific branches to show only their relevant files. Without branch isolation, developers working on a specific project would see all other projects' files, creating confusion and potential conflicts.

## Intended Behavior

Configure git branch isolation so that:
1. **Project Branches**: Each project branch shows only files relevant to that project
2. **File Visibility**: When checking out a project branch, only that project's files are visible in the working directory
3. **History Integration**: Each branch contains the complete commit history from the original project repository
4. **Sparse Checkout**: Use git sparse-checkout to control file visibility per branch
5. **Branch Switching**: Seamless switching between project contexts

## Suggested Implementation Steps

### 1. Design Branch Structure
```
master - contains all projects and serves as complete collection
├── adroit - only adroit/ files visible
├── progress-ii - only progress-ii/ files visible  
├── progress-ii-gamestate - only progress-ii/game-state/ files visible
├── risc-v-university - only risc-v-university/ files visible
├── magic-rumble - only magic-rumble/ files visible
└── handheld-office - only handheld-office/ files visible
```

### 2. Implement Git Subtree Integration
For each project using extracted histories from Issue 004:
```bash
# Create branch and import history
git checkout --orphan project-branch-name
git rm -rf .
git subtree add --prefix=project-name extracted-history-bundle master --squash
```

### 3. Configure Sparse-Checkout
Set up sparse-checkout patterns for each branch:
```bash
# Enable sparse-checkout
git config core.sparseCheckout true

# Configure .git/info/sparse-checkout for each branch
echo "project-directory/*" > .git/info/sparse-checkout
git read-tree -m -u HEAD
```

### 4. Create Branch-Specific Git Attributes
Configure `.gitattributes` files for each branch:
- Ensure project-specific file handling
- Set up appropriate merge strategies
- Configure diff and merge tools per project type

### 5. Implement Branch Switching Automation
Create helper scripts for branch management:
```bash
# -- {{{ switch_to_project_branch
function switch_to_project_branch() {
    local project_name="$1"
    git checkout "$project_name"
    git config core.sparseCheckout true
    echo "$project_name/*" > .git/info/sparse-checkout
    git read-tree -m -u HEAD
}
# }}}
```

### 6. Validate Isolation
Test each branch to ensure:
- Only relevant project files are visible
- Git operations (add, commit, push) work correctly
- History is preserved and accessible
- No interference between different project branches

### 7. Handle Special Cases
- **Shared Libraries**: Decide if shared code should be visible across branches
- **Documentation**: Determine if project-level docs should be accessible from project branches
- **Scripts**: Handle utility scripts that might be used by multiple projects

## Implementation Details

### Sparse-Checkout Configuration per Branch
```
# For adroit branch
adroit/
!adroit/.git

# For progress-ii branch  
progress-ii/
!progress-ii/.git
!progress-ii/game-state/.git

# For risc-v-university branch
risc-v-university/
!risc-v-university/.git
```

### Branch Switching Workflow
```bash
#!/bin/bash
# Switch to project and configure visibility
project_branch="$1"
git checkout "$project_branch"
echo "$project_branch/*" > .git/info/sparse-checkout
git read-tree -m -u HEAD
echo "Switched to $project_branch - only relevant files visible"
```

### Integration with Git Hooks
Set up git hooks to automatically configure sparse-checkout on branch switch:
```bash
# .git/hooks/post-checkout
#!/bin/bash
branch_name=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch_name" != "master" ]]; then
    echo "$branch_name/*" > .git/info/sparse-checkout
    git read-tree -m -u HEAD
fi
```

## Related Documents
- `004-extract-project-histories.md` - Source of histories to integrate
- `006-initialize-master-branch.md` - Master branch setup with all projects
- `007-remote-repository-setup.md` - Remote configuration for isolated branches

## Tools Required
- Git subtree commands
- Git sparse-checkout configuration
- Branch management utilities
- Shell scripting for automation
- Git hooks for workflow integration

## Metadata
- **Priority**: High
- **Complexity**: High
- **Estimated Time**: 2-3 hours
- **Dependencies**: Issue 004 (extracted project histories)
- **Impact**: Developer workflow, project organization

## Success Criteria
- Each project branch shows only relevant files
- Complete commit history preserved in each branch
- Seamless branch switching with automatic file visibility
- No conflicts between project branches
- Git operations work correctly in isolated context
- Helper scripts and automation in place
- Validation that isolation works as intended